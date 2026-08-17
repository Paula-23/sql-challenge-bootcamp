
--- PART A: Connecting the dots
--- Step 1. Copy tables from original schema to my schema


CREATE TABLE s_paulasofiaherreraespejel.customers_ss as
SELECT *
FROM shop_smart.customers;

CREATE TABLE s_paulasofiaherreraespejel.order_items AS
SELECT *
FROM shop_smart.order_items;

CREATE TABLE s_paulasofiaherreraespejel.orders AS
SELECT *
FROM shop_smart.orders;

CREATE TABLE s_paulasofiaherreraespejel.products AS
SELECT *
FROM shop_smart.products;

CREATE TABLE s_paulasofiaherreraespejel.promotions AS
SELECT *
FROM shop_smart.promotions;

--- Step 2. Recreate constraints (primary keys, foriegn keys, indexes)

/*
 * PK = cannot be null, cannot be duplicated and uniquely identifies one row
 * FK = references a PK in another table and creates relationships between tables
 */

-- Primary Keys

ALTER TABLE customers_ss 
ADD CONSTRAINT customers_pk PRIMARY KEY (customer_id);

alter table products 
add constraint products_pk primary key (product_id);

ALTER TABLE orders
ADD CONSTRAINT orders_pk PRIMARY KEY (order_id);

alter table order_items
add constraint order_items_pk primary key (order_item_id);

alter table promotions
add constraint  promotion_id_pk primary key (promotion_id);

-- Foreign Keys

ALTER TABLE orders
ADD CONSTRAINT orders_customer_fk
FOREIGN KEY (customer_id)
REFERENCES customers_ss (customer_id);

ALTER TABLE order_items
ADD CONSTRAINT order_items_order_fk
FOREIGN KEY (order_id)
REFERENCES orders (order_id);

ALTER TABLE order_items
ADD CONSTRAINT order_items_product_fk
FOREIGN KEY (product_id)
REFERENCES products (product_id);

ALTER TABLE promotions
ADD CONSTRAINT promotions_product_fk
FOREIGN KEY (product_id)
REFERENCES products (product_id);

--- PART B: Solutions

-- 1. `Customer segmentation:` How many customers are from each region? 

/* 
 * Segmentation Analysis aims to categorize customers into distinct groups based on 
 * their purchasing behavior and demographic characteristics. This segmentation helps 
 * businesses tailor their marketing strategies, enhance customer experience, and 
 * improve overall business performance.
 */

SELECT
    region,
    COUNT(*) AS customer_count
FROM customers_ss
GROUP BY region
order by customer_count desc;

-- 2. `Regional performance:` What’s the average value of an order per region?

SELECT
    c.region,
    round(AVG(o.total_amount),2) AS avg_order_total
FROM orders o
JOIN customers_ss c
  ON o.customer_id = c.customer_id
GROUP BY c.region
order by avg_order_total desc;

-- 3. `Product mix analysis:` 
-- 3.1. Which product categories have the highest average price?

select p.category, round(AVG(p.unit_price),2) as avg_unit_price
from products p
group by p.category 
order by avg_unit_price desc;

-- 3.2. Which product categories have the highest average price per region?

/* Tables involved:
 * products      (product_id, category, price)
 * order_items   (product_id, order_id)
 * orders        (order_id, customer_id)
 * customers     (customer_id, region)
 */

SELECT
    c.region,
    p.category,
    round(AVG(p.unit_price),2) AS avg_price
FROM products p
JOIN order_items oi
  ON p.product_id = oi.product_id
JOIN orders o
  ON oi.order_id = o.order_id
JOIN customers_ss c
  ON o.customer_id = c.customer_id
GROUP BY c.region, p.category
ORDER BY c.region, avg_price DESC;

-- 4. `Trend analysis:` Find the total revenue generated per month.

/*
 * Revenue = money earned from completed orders
 * Per month = grouped by the month the order happened
 */

--- sol. 1: Untidy
select 
	DATE_TRUNC('month', o.order_date) AS month,
	round(sum(o.total_amount),2) as total_revenue
from orders o
group by month
order by month;

--- sol 2.: Tidy
SELECT
    EXTRACT(YEAR FROM order_date) AS year,
    EXTRACT(MONTH FROM order_date) AS month,
    round(SUM(o.total_amount),2) AS total_revenue
FROM orders o
GROUP BY 1, 2
ORDER BY year, month;

--- sol 3.: Even tidier

SELECT
    EXTRACT(YEAR FROM order_date) AS year,
    TO_CHAR(order_date, 'Mon') AS month_name,
    round(SUM(total_amount),2) AS total_revenue
FROM orders
GROUP BY year, month_name
ORDER BY year, MIN(EXTRACT(MONTH FROM order_date));

-- 5. `Product performance:` List the top 10 products by total sales quantity.

/* p.product_name, p.product_type
 * oi.quantity 
 * Order by tot_sales_quant, LIMIT 10
 */

select 
	p.category, 
	p.product_name, 
	SUM(oi.quantity) as tot_sales_quant,
	SUM(oi.quantity * p.unit_price) AS total_revenue
from products p
JOIN order_items oi
  ON p.product_id = oi.product_id
group by p.category, p.product_name
order by tot_sales_quant desc
limit 10;

-- 6. `Customer loyalty / retention:` Which customer(s) placed more than 2 orders in the past 6 months? (assume current date)

SELECT
    c.customer_id,
    COUNT(o.order_id) AS num_orders
FROM orders o
JOIN customers_ss c
  ON o.customer_id = c.customer_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY c.customer_id
HAVING COUNT(o.order_id) > 2
ORDER BY num_orders DESC;

-- 7. `Pricing analysis:` Find product categories whose average order item discount is greater than 10%.

SELECT 
	p.category, 
	ROUND(AVG(oi.discount),2) AS avg_order_disc
FROM products p
JOIN order_items oi 
ON p.product_id = oi.order_item_id 
WHERE oi.discount > 0
GROUP BY p.category
HAVING AVG(oi.discount) > 0.1
ORDER BY avg_order_disc DESC; 

-- 8. `Regional target checking:` Which regions have generated more than $150,000 in total sales?
-- 

SELECT
    MAX(total_amount) AS max_order, -- 7,056
    MIN(total_amount) AS min_order, -- 55
    AVG(total_amount) AS avg_order -- 2,161
FROM orders;

--- Solution 1: overall

SELECT
    COUNT(*) AS num_large_orders
FROM orders
WHERE total_amount > 1500;

SELECT
	c.region, round(sum(o.total_amount),2) AS total_sales
FROM customers_ss c
JOIN orders o 
ON c.customer_id = o.customer_id
GROUP BY c.region
HAVING sum(o.total_amount) > 150000
ORDER BY total_sales DESC;

--- Solution 2: per region
SELECT
    c.region,
    COUNT(*) AS num_large_orders
FROM orders o
JOIN customers_ss c
  ON o.customer_id = c.customer_id
WHERE o.total_amount > 1500
GROUP BY c.region
ORDER BY num_large_orders DESC;

-- 9. `RFM-style segmentation:` Identify customers whose average order value is above the overall average.

SELECT c.customer_id, round(AVG(o.total_amount),2) AS avg_value
FROM customers_ss c
JOIN orders o
ON c.customer_id = o.customer_id
GROUP BY c.customer_id
HAVING AVG(o.total_amount) > (SELECT AVG(total_amount) FROM orders)
ORDER BY AVG(o.total_amount) DESC
LIMIT 5;

-- 10. `Catalog management:` Which products have never been sold?

SELECT oi.product_id, count(DISTINCT oi.order_id) AS n_orders
FROM order_items oi
GROUP BY oi.product_id 
ORDER BY n_orders 

SELECT p.product_id, p.product_name
FROM products p
LEFT JOIN order_items oi
  ON p.product_id = oi.product_id
WHERE oi.product_id IS NULL
ORDER BY p.product_name;

-- 11. `Regional sales by segment:` Find the total revenue per category and region for the last 6 months, 
-- showing only categories with total revenue above $1,000.

SELECT
    p.category,
    c.region,
    SUM(oi.quantity * p.unit_price) AS total_revenue
FROM orders o
JOIN customers_ss c
  ON o.customer_id = c.customer_id
JOIN order_items oi
  ON o.order_id = oi.order_id
JOIN products p
  ON oi.product_id = p.product_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY p.category, c.region
HAVING SUM(oi.quantity * p.unit_price) > 1000
ORDER BY total_revenue DESC;

-- 12. `Cross-category affinity:` Which customers bought products from more than 3 categories?

SELECT
    c.customer_id,
    COUNT(DISTINCT p.category) AS num_categories
FROM customers_ss c
JOIN orders o
  ON c.customer_id = o.customer_id
JOIN order_items oi
  ON o.order_id = oi.order_id
JOIN products p
  ON oi.product_id = p.product_id
GROUP BY c.customer_id
HAVING COUNT(DISTINCT p.category) > 3
ORDER BY num_categories DESC;

-- 13. `Promotion performance:` Calculate the average discount applied per product category, 
-- but only include categories with at least 500 items sold.


-- Average discount per category
SELECT 
	p.category, 
	round(AVG (oi.discount),5) AS avg_discount
FROM order_items oi
JOIN products p
ON oi.product_id = p.product_id 
GROUP BY p.category; 

--- Total items sold per category 
SELECT
    p.category,
    SUM(oi.quantity) AS total_items_sold
FROM order_items oi
JOIN products p
  ON oi.product_id = p.product_id
GROUP BY p.category
--HAVING SUM(oi.quantity) >= 500
ORDER BY total_items_sold DESC;

-- Joint results
SELECT
	p.category, 
	SUM(oi.quantity) AS total_items_sold,
	round(AVG (oi.discount),5) AS avg_discount
FROM order_items oi
JOIN products p
ON oi.product_id = p.product_id
GROUP BY p.category
HAVING SUM(oi.quantity) >= 500
ORDER BY avg_discount  DESC;

-- 14. `Campaign analysis:` Identify the top 5 customers who spent the most during an active promotion period.

/*
 * A purchase is considered during an active promotion period 
 * if
 * order_date BETWEEN promotions.start_date AND promotions.end_date
 */

-- solution 1
SELECT
	c.customer_id,
	o.total_amount
FROM customers_ss c
JOIN orders o
ON c.customer_id = o.customer_id
JOIN order_items oi 
ON o.order_id = oi.order_id 
JOIN promotions pr
ON pr.product_id = oi.product_id
WHERE o.order_date BETWEEN pr.start_date AND pr.end_date
LIMIT 5;

-- solution 2
SELECT
    c.customer_id,
    SUM(oi.quantity * p.unit_price) AS total_spent
--    COUNT(DISTINCT o.order_id) AS num_promoted_orders,
--    SUM(oi.quantity * p.price) / COUNT(DISTINCT o.order_id)
FROM customers_ss c
JOIN orders o
  ON c.customer_id = o.customer_id
JOIN order_items oi
  ON o.order_id = oi.order_id
JOIN products p
  ON oi.product_id = p.product_id
JOIN promotions pr
  ON p.product_id = pr.product_id
 AND o.order_date BETWEEN pr.start_date AND pr.end_date
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 5;

-- 15. `Promotion effectiveness ROI :` For each promotion, calculate the total sales of that product during the promotion period).

/*
 *  total sales of the promoted products during the promtion
 */

SELECT
    pr.promotion_id,
    SUM(oi.quantity * p.unit_price) AS promo_revenue
FROM promotions pr
JOIN products p
  ON pr.product_id = p.product_id
JOIN order_items oi
  ON p.product_id = oi.product_id
JOIN orders o
  ON oi.order_id = o.order_id
WHERE o.order_date BETWEEN pr.start_date AND pr.end_date
GROUP BY pr.promotion_id
ORDER BY promo_revenue DESC;

/*
 * Total Incremental Revenue is the additional income generated by a specific business action—such as a marketing campaign, 
 * new product launch, or price increase—that exceeds the baseline revenue. It measures the direct financial impact of a 
 * strategy by calculating the difference between total revenue during the action and total revenue before or without it.
 * 
 * TIR = TR with Action - Baseline Revenue 
 */

--- ORDERS WITHIN PROMOTION PERIOD

-- total incremental revenue = q*px of all sold items with a discount - after discount

SELECT
	SUM(oi.quantity) AS tot_q,
	SUM(oi.unit_price) AS tot_px,
	SUM(oi.quantity * oi.unit_price) AS total_revenue,
CASE
	WHEN oi.discount > 0 THEN 'YES'
	ELSE 'NO'
	END AS promotion
FROM order_items oi
GROUP BY 
	CASE
		WHEN oi.discount > 0 THEN 'YES'
		ELSE 'NO'
	END;


-- Average daily revenue BEFORE promotion
WITH baseline AS 
(
    SELECT
        pr.promotion_id,
        AVG(oi.quantity * p.unit_price) AS avg_daily_revenue
    FROM promotions pr
    JOIN products p ON pr.product_id = p.product_id
    JOIN order_items oi ON p.product_id = oi.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_date < pr.start_date
    GROUP BY pr.promotion_id
)
SELECT
    pr.promotion_id,
    SUM(oi.quantity * p.unit_price) 
    - b.avg_daily_revenue
      * (pr.end_date - pr.start_date + 1) AS incremental_revenue
FROM promotions pr
JOIN baseline b ON pr.promotion_id = b.promotion_id
JOIN products p ON pr.product_id = p.product_id
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_date BETWEEN pr.start_date AND pr.end_date
GROUP BY pr.promotion_id, b.avg_daily_revenue, pr.start_date, pr.end_date;

-- 16. `Post-campaign diagnostic:` Find products that had a promotion but still generated less than the average sales of their category.

/*
 * Products with promtion > 0
 * Total Amount < Avg Total Amount 
 * Per Category 
 */

WITH 
	promos AS (
	SELECT oi.product_id, p.category, sum(oi.quantity * oi.unit_price) AS sales
	FROM order_items oi 
	LEFT JOIN products p 
	ON oi.product_id = p.product_id 
	WHERE oi.discount > 0
	GROUP BY oi.product_id, p.category
	ORDER BY oi.product_id), 
	averages AS (
	SELECT a.category, Round(AVG(a.sales),2) AS avg_sales
	FROM (
		SELECT oi.product_id, p.category, sum(oi.quantity * oi.unit_price) AS sales
		FROM order_items oi 
		LEFT JOIN products p 
		ON oi.product_id = p.product_id
		GROUP BY oi.product_id, p.category
		ORDER BY oi.product_id)	a
	GROUP BY a.category )
SELECT 
po.product_id, 
po.category, 
po.sales, 
av.avg_sales 
FROM promos po
LEFT JOIN averages av
ON po.category = av.category
WHERE po.sales < av.avg_sales

-- 17. `Trend evaluation:` List regions where the average order value increased month over month.

/*
 * Truncate by month and year
 * Avg(total amount)
 * Regions
 */

-- 18.  `Cross-sell / market basket/ product association:` Find customers who bought both Electronics and Sports products.
-- SOURCE: https://www.youtube.com/watch?v=wSo-Cntp_rk 


ems --- each order has its individual order id
WHERE order_id = 25 


-- Which two producs have been sold together the most?


-- 19. `Market penetration:` Compute the total number of unique customers per category and identify categories that have  least 40 unique buyers.




-- 20. `Pricing / margin impact:` Find the most discounted products (by total discount amount applied) in each category.




