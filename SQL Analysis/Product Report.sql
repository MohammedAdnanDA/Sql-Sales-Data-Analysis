/*
Product Report

Purpose:
This report consolidates key product metrics and behaviors.

Highlights:

1. Gathers essential fields such as product name, category, subcategory, and cost.

2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.

3. Aggregates product-level metrics:
   - Total orders
   - Total sales
   - Total quantity sold
   - Total customers (unique)
   - Lifespan (in months)

4. Calculates valuable KPIs:
   - Recency (months since last sale)
   - Average Order Revenue (AOR)
   - Average Monthly Revenue
*/


-- 1. Gathers essential fields such as product name, category, subcategory, and cost.

CREATE VIEW gold.report_products AS
WITH base_query AS (
SELECT 
	f.order_number,
	f.customer_key,
	f.order_date,
	f.sales_amount,
	f.quantity,
	p.product_key,
	p.product_name,
	p.category,
	p.subcategory,
	p.cost
FROM
	gold.dim_products p
LEFT JOIN 
	gold.fact_sales f 
ON p.product_key = f.product_key
WHERE f.order_date IS NOT NULL),

product_aggregations AS (
SELECT 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
	MAX(order_date) AS last_sale_date,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantities,
	COUNT(DISTINCT customer_key) AS total_customers,
	COUNT(DISTINCT order_number) AS total_orders,
	ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity,0)),1) AS avg_selling_price
FROM 
	base_query
GROUP BY 
	product_key,
	product_name,
	category,
	subcategory,
	cost)

SELECT 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	last_sale_date,
	DATEDIFF(MONTH,last_sale_date,GETDATE()) AS recency,
	CASE
		WHEN total_sales > 50000 THEN 'Higher Performer'
		WHEN total_sales < 10000 THEN 'Mid Range'
		ELSE 'Lower Performer'
	END AS product_segment,
	lifespan,
	total_orders,
	total_sales,
	total_quantities,
	total_customers,
	avg_selling_price,
	-- Average order revenue
	CASE
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	END AS avg_order_revenue,
	-- Average monthly revenue
	CASE 
		WHEN lifespan = 0 THEN total_sales
		ELSE total_sales / lifespan
	END AS avg_monthly_revenue
FROM 
	product_aggregations;