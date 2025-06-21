-- Analyze sales over time

SELECT
YEAR(order_date) AS order_year,
MONTH(order_date) AS order_month,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date),MONTH(order_date)
ORDER BY YEAR(order_date),MONTH(order_date);




SELECT
DATETRUNC(year, order_date) AS order_date,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(year, order_date)
ORDER BY DATETRUNC(year, order_date);



-- calculate the total sales per month
-- and the running total of the sales over time

SELECT 
order_date,
total_sales,
SUM(total_sales)OVER(ORDER BY order_date) AS running_total_sales,
AVG(avg_price)OVER(ORDER BY order_date) AS moving_avg_price
FROM
(SELECT 
DATETRUNC(YEAR,order_date) AS order_date,
SUM(sales_amount) AS total_sales,
AVG(price) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR,order_date)
) t

/*Analyzing the yearly performance of the products by comparing each product sales to both 
-- average sales performance and previous year's sales.*/

WITH yearly_sales_data AS (
SELECT
	YEAR(f.order_date) AS order_year,
	p.product_name,
	SUM(f.sales_amount) AS current_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY 
YEAR(f.order_date),
p.product_name
)
SELECT 
order_year,
product_name,
current_sales,
AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
current_sales - AVG(current_sales) OVER (PARTITION BY product_name)  AS diff_avg,
CASE
	WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
	WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
	ELSE 'Avg'
END avg_change,
LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS py_sales,
current_sales -LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS diff_py,
CASE
	WHEN current_sales -LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
	WHEN current_sales -LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
	ELSE 'No Change'
END py_change
FROM yearly_sales_data
ORDER BY product_name,order_year;



-- Which category contributes the most to the overall sales?

WITH category_sales AS(
SELECT 
category,
SUM(sales_amount) AS total_sales 
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
GROUP BY category
)
SELECT 
category,
total_sales,
SUM(total_sales)OVER() AS overall_sales,
CONCAT(ROUND((CAST(total_sales AS FLOAT)/SUM(total_sales)OVER()) * 100,2),'%') AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC;



/*Segment products into cost ranges and 
count how many products fall into each segment*/

WITH product_segments AS(
SELECT 
product_key,
product_name,
cost,
CASE
	WHEN cost < 100 THEN 'Below 100'
	WHEN cost BETWEEN 100 AND 500 THEN '100-500'
	WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
	ELSE 'Above 1000'
END cost_range
FROM gold.dim_products)
SELECT 
	cost_range,
	COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY COUNT(product_key) DESC;


-- Group customers into three segments based on their spending behavior:
-- VIP: at least 12 months of history and spending more than €5,000.
-- Regular: at least 12 months of history but spending €5,000 or less.
-- New: lifespan less than 12 months.
-- and find the total number of customers by each group.

WITH customer_spending AS (
SELECT 
	c.customer_key,
	SUM(f.sales_amount) AS total_spending,
	MIN(f.order_date) AS first_order,
	MAX(f.order_date) AS last_order,
	DATEDIFF(MONTH, MIN(f.order_date), MAX(f.order_date)) AS lifespan
FROM gold.dim_customers c
LEFT JOIN gold.fact_sales f
ON c.customer_key = f.customer_key
GROUP BY c.customer_key),
behaviour as (SELECT 
	customer_key,
	total_spending,
	CASE
		WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
		WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
		ELSE 'New'
	END status
FROM customer_spending)
SELECT 
	status,
	COUNT(customer_key) AS customers
FROM behaviour 
GROUP BY status
ORDER BY COUNT(customer_key) DESC;
