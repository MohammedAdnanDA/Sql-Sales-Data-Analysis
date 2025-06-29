-- Customer Report

-- ---
-- Purpose:
-- This report consolidates key customer metrics and behaviors

-- Highlights:

-- 1. Gathers essential fields such as names, ages, and transaction details.

-- 2. Segments customers into categories (VIP, Regular, New) and age groups.

-- 3. Aggregates customer-level metrics:
--    - total orders
--    - total sales
--    - total quantity purchased
--    - total products
--    - lifespan (in months)

-- 4. Calculates valuable KPIs:
--    - recency (months since last order)
--    - average order value
--    - average monthly spend

-- 1) Retrive core columns from table

CREATE VIEW gold.report_customers AS 
WITH base_query AS (
    SELECT 
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON f.customer_key = c.customer_key
    WHERE f.order_date IS NOT NULL
),
customer_summary AS (
    SELECT 
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantities,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order_date,
        MIN(order_date) AS first_order_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
        DATEDIFF(MONTH, MAX(order_date), GETDATE()) AS recency
    FROM base_query
    GROUP BY 
        customer_key, customer_number, customer_name, age
)
SELECT 
    *,
    CASE 
        WHEN age < 20 THEN 'Teenager'
        WHEN age BETWEEN 20 AND 45 THEN 'Adult'
        ELSE 'Old'
    END AS age_group,

    CASE
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS status,

    CASE 
        WHEN total_sales = 0 THEN 0
        ELSE total_sales  / total_orders
    END AS avg_order_value,

    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales  / lifespan
    END AS avg_monthly_spend

FROM customer_summary;	
