

-- 1. Revenue Overview

-- 1.1 What is the total revenue from completed transactions?
SELECT ROUND(SUM(usd_price), 2) AS total_revenue
FROM orders o
LEFT JOIN order_status os ON o.id = os.order_id
WHERE os.refund_ts IS NULL;


-- 1.2 What is the average order value?
SELECT ROUND(AVG(usd_price), 2) AS average_order_value
FROM orders;


-- 1.3 Which purchase platforms generate more revenue?
SELECT purchase_platform, ROUND(SUM(usd_price), 2) AS revenue
FROM orders
GROUP BY purchase_platform
ORDER BY revenue DESC;


-- 2. Time-Based Trends

-- 2.1 How does revenue vary by month?
SELECT DATE_TRUNC('month', purchase_ts) AS month, ROUND(SUM(usd_price), 2) AS monthly_revenue
FROM orders
GROUP BY month
ORDER BY month;


-- 2.2 Which day of the week has the highest average sales?
SELECT TO_CHAR(purchase_ts, 'Day') AS weekday, ROUND(SUM(usd_price), 2) AS revenue
FROM orders
GROUP BY weekday
ORDER BY revenue DESC;



-- 3. Refund Behavior


-- 3.1 What percentage of orders are refunded?
SELECT ROUND(COUNT(os.order_id) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS refund_rate_percentage
FROM order_status os
WHERE refund_ts IS NOT NULL;


-- 3.2 Which products are refunded most often?
SELECT o.product_name, COUNT(*) AS refund_count
FROM orders o
JOIN order_status os ON o.id = os.order_id
WHERE os.refund_ts IS NOT NULL
GROUP BY o.product_name
ORDER BY refund_count DESC
LIMIT 5;


-- 3.3 What is the average time between purchase and refund?
SELECT ROUND(AVG(DATE_PART('day', refund_ts - purchase_ts)), 2) AS avg_days_to_refund
FROM order_status
WHERE refund_ts IS NOT NULL;



-- 4. Customer Segmentation

-- 4.1 Do loyalty members generate more revenue than standard users?
SELECT 
  CASE WHEN loyalty_program = 1 THEN 'Loyalty Member' ELSE 'Standard Customer' END AS customer_type,
  ROUND(SUM(usd_price), 2) AS total_revenue
FROM orders o
JOIN customers c ON o.customer_id = c.id
GROUP BY customer_type;


-- 4.2 Which account creation methods are most popular?
SELECT account_creation_method, COUNT(*) AS total_customers
FROM customers
GROUP BY account_creation_method
ORDER BY total_customers DESC;


-- 5. Delivery Efficiency

-- 5.1 What is the average time from shipping to delivery?
SELECT ROUND(AVG(DATE_PART('day', delivery_ts - ship_ts)), 2) AS avg_delivery_days
FROM order_status
WHERE delivery_ts IS NOT NULL AND ship_ts IS NOT NULL;


-- 5.2 Are there delivery delays in specific regions?
SELECT g.region, ROUND(AVG(DATE_PART('day', delivery_ts - ship_ts)), 2) AS avg_delivery_days
FROM order_status os
JOIN orders o ON os.order_id = o.id
JOIN customers c ON o.customer_id = c.id
JOIN geo_lookup g ON c.country_code = g.country
WHERE delivery_ts IS NOT NULL AND ship_ts IS NOT NULL
GROUP BY g.region
ORDER BY avg_delivery_days DESC;


-- 6. Geographic Insights

-- 6.1 Which countries generate the highest revenue?
SELECT c.country_code, ROUND(SUM(o.usd_price), 2) AS total_revenue
FROM orders o
JOIN customers c ON o.customer_id = c.id
GROUP BY c.country_code
ORDER BY total_revenue DESC;


-- 6.2 What regions have the highest refund rates?
WITH region_orders AS (
  SELECT g.region, o.id AS order_id
  FROM orders o
  JOIN customers c ON o.customer_id = c.id
  JOIN geo_lookup g ON c.country_code = g.country
),
region_refunds AS (
  SELECT region, COUNT(*) AS refund_count
  FROM region_orders ro
  JOIN order_status os ON ro.order_id = os.order_id
  WHERE os.refund_ts IS NOT NULL
  GROUP BY region
)
SELECT 
  ro.region,
  rr.refund_count * 100.0 / COUNT(ro.order_id) AS refund_rate_percentage
FROM region_orders ro
LEFT JOIN region_refunds rr ON ro.region = rr.region
GROUP BY ro.region, rr.refund_count;



-- 7. Product & Customer Insights

-- 7.1 Who are our top 5 spending customers?
SELECT o.customer_id, ROUND(SUM(o.usd_price), 2) AS total_spent
FROM orders o
GROUP BY o.customer_id
ORDER BY total_spent DESC
LIMIT 5;


-- 7.2 Which products have the highest average order value?
SELECT product_name, ROUND(AVG(usd_price), 2) AS avg_order_value
FROM orders
GROUP BY product_name
ORDER BY avg_order_value DESC
LIMIT 5;


-- 8. Advanced Metrics

-- 8.1 What is each customer's lifetime revenue?
SELECT customer_id, SUM(usd_price) AS lifetime_value
FROM orders
GROUP BY customer_id;


-- 8.2 Use a window function to rank customers by lifetime value
SELECT 
  customer_id,
  SUM(usd_price) AS lifetime_value,
  RANK() OVER (ORDER BY SUM(usd_price) DESC) AS revenue_rank
FROM orders
GROUP BY customer_id;

-- 8.3 What is the 7-day moving average of revenue?
WITH daily_sales AS (
  SELECT DATE(purchase_ts) AS day, SUM(usd_price) AS revenue
  FROM orders
  GROUP BY day
)
SELECT 
  day,
  ROUND(AVG(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS moving_avg_7d
FROM daily_sales;



-- 9.1 Are refunds more common among high-value orders?
SELECT 
  CASE 
    WHEN usd_price > 500 THEN 'High Value'
    WHEN usd_price BETWEEN 100 AND 500 THEN 'Mid Value'
    ELSE 'Low Value'
  END AS order_value_group,
  COUNT(*) FILTER (WHERE os.refund_ts IS NOT NULL) AS refunded_orders,
  COUNT(*) AS total_orders,
  ROUND(COUNT(*) FILTER (WHERE os.refund_ts IS NOT NULL) * 100.0 / COUNT(*), 2) AS refund_rate
FROM orders o
LEFT JOIN order_status os ON o.id = os.order_id
GROUP BY order_value_group;


-- 9.2 What percentage of revenue comes from the top 10% of customers?
WITH customer_spend AS (
  SELECT customer_id, SUM(usd_price) AS total_spent
  FROM orders
  GROUP BY customer_id
),
ranked AS (
  SELECT *, NTILE(10) OVER (ORDER BY total_spent DESC) AS spend_decile
  FROM customer_spend
)
SELECT 
  spend_decile,
  ROUND(SUM(total_spent), 2) AS revenue_by_decile
FROM ranked
GROUP BY spend_decile
ORDER BY spend_decile;


-- 9.3 Which customers placed multiple orders within the same week?
WITH order_weeks AS (
  SELECT customer_id, DATE_TRUNC('week', purchase_ts) AS order_week, COUNT(*) AS weekly_orders
  FROM orders
  GROUP BY customer_id, order_week
)
SELECT * 
FROM order_weeks
WHERE weekly_orders > 1
ORDER BY weekly_orders DESC;


-- 9.4 What is the average number of days between purchases for each customer?
WITH ordered_dates AS (
  SELECT customer_id, purchase_ts,
         LAG(purchase_ts) OVER (PARTITION BY customer_id ORDER BY purchase_ts) AS prev_purchase
  FROM orders
)
SELECT 
  customer_id,
  ROUND(AVG(DATE_PART('day', purchase_ts - prev_purchase)), 2) AS avg_days_between_orders
FROM ordered_dates
WHERE prev_purchase IS NOT NULL
GROUP BY customer_id
ORDER BY avg_days_between_orders;


-- 9.5 Use ROW_NUMBER to find each customer's first purchase
WITH ranked_orders AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY purchase_ts) AS rn
  FROM orders
)
SELECT customer_id, id AS first_order_id, purchase_ts
FROM ranked_orders
WHERE rn = 1;

-- 9.6 Which products have the widest pricing variance?
SELECT product_name,
       ROUND(AVG(usd_price), 2) AS avg_price,
       ROUND(STDDEV(usd_price), 2) AS price_stddev
FROM orders
GROUP BY product_name
ORDER BY price_stddev DESC
LIMIT 5;


-- 9.7 Are some marketing channels associated with faster delivery times?
SELECT 
  c.marketing_channel,
  ROUND(AVG(DATE_PART('day', delivery_ts - ship_ts)), 2) AS avg_delivery_days
FROM order_status os
JOIN orders o ON os.order_id = o.id
JOIN customers c ON o.customer_id = c.id
WHERE delivery_ts IS NOT NULL AND ship_ts IS NOT NULL
GROUP BY c.marketing_channel
ORDER BY avg_delivery_days;


-- 9.8 What is the median order value per platform?
SELECT purchase_platform,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY usd_price) AS median_order_value
FROM orders
GROUP BY purchase_platform;


-- 9.9 How many customers placed more than 5 orders total?
SELECT customer_id, COUNT(*) AS total_orders
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 5
ORDER BY total_orders DESC;


-- 9.10 Which products are frequently bought together (same customer)?
WITH customer_product AS (
  SELECT customer_id, product_name
  FROM orders
  GROUP BY customer_id, product_name
),
product_pairs AS (
  SELECT a.product_name AS product_1, b.product_name AS product_2, COUNT(*) AS pair_count
  FROM customer_product a
  JOIN customer_product b ON a.customer_id = b.customer_id AND a.product_name < b.product_name
  GROUP BY product_1, product_2
)
SELECT * FROM product_pairs
ORDER BY pair_count DESC
LIMIT 10;
