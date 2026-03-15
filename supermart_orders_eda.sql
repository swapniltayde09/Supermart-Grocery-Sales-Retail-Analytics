-- ==========================================
-- Phase 1: Database Setup & Schema
-- ==========================================
-- 1.  Create database
CREATE DATABASE IF NOT EXISTS supermart_db;
USE supermart_db;

-- Drop table if exists
DROP TABLE IF EXISTS orders;

-- Create table with proper types
CREATE TABLE orders (
    `Order ID` VARCHAR(10) PRIMARY KEY,
    `Customer Name` VARCHAR(50),
    Category VARCHAR(50),
    `Sub Category` VARCHAR(100),
    City VARCHAR(50),
    `Order Date` DATE,
    Region VARCHAR(20),
    Sales DECIMAL(10,2),
    Discount DECIMAL(5,4),
    Profit DECIMAL(10,2),
    State VARCHAR(20)
);

SHOW VARIABLES LIKE 'secure_file_priv';

-- Load Data
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/supermart_dataset_cleaned.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(`Order ID`, `Customer Name`, Category, `Sub Category`, City, @order_date_raw, Region, Sales, Discount, Profit, State)
SET `Order Date` = STR_TO_DATE(@order_date_raw, '%d-%m-%Y');

-- Row count
SELECT COUNT(*) AS total_rows FROM orders;

-- Schema preview
DESCRIBE orders;

-- Sample data
SELECT * FROM orders LIMIT 10;

-- Date range check
SELECT MIN(`Order Date`) AS earliest, MAX(`Order Date`) AS latest FROM orders; 

-- Nulls check
SELECT 
    SUM(CASE WHEN `Order ID` IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    COUNT(*) AS total FROM orders;
    
-- ========================================
-- Phase 2: Data Understanding
-- ========================================
-- Overall stats
SELECT 
    COUNT(*) AS total_orders,
    COUNT(DISTINCT `Customer Name`) AS unique_customers,
    COUNT(DISTINCT City) AS unique_cities,
    COUNT(DISTINCT Category) AS unique_categories,
    MIN(`Order Date`) AS first_order,
    MAX(`Order Date`) AS last_order,
    ROUND(AVG(Sales), 2) AS avg_sales,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit
FROM orders;

-- Duplicates check
SELECT `Order ID`, COUNT(*) FROM orders GROUP BY `Order ID` HAVING COUNT(*) > 1;

-- Nulls per column
SELECT 
    SUM(CASE WHEN `Customer Name` IS NULL THEN 1 ELSE 0 END) AS null_customers,
    SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN Sales <= 0 THEN 1 ELSE 0 END) AS invalid_sales
FROM orders;

-- Category & Region distribution
SELECT Category, COUNT(*) AS order_count, ROUND(AVG(Sales), 2) AS avg_sales_per_order
FROM orders GROUP BY Category ORDER BY order_count DESC LIMIT 10;

SELECT Region, COUNT(*) AS order_count, ROUND(SUM(Sales), 2) AS total_region_sales
FROM orders GROUP BY Region;

-- =========================================
-- Phase 3: Feature Engineering
-- =========================================
-- Add columns for profit margin, order year/month, recency
ALTER TABLE orders 
ADD COLUMN profit_margin DECIMAL(6,4),
ADD COLUMN order_year INT,
ADD COLUMN order_month INT,
ADD COLUMN customer_recency INT;  -- Days since last order (relative to max date)

-- Populate
UPDATE orders 
SET profit_margin = (Profit / Sales) * 100;

UPDATE orders 
SET order_year = YEAR(`Order Date`),
    order_month = MONTH(`Order Date`);

-- Recency: assumes run in 2026, but relative to dataset max
-- Create temp table with last order per customer
CREATE TEMPORARY TABLE customer_last_order AS
SELECT `Customer Name`, MAX(`Order Date`) AS last_order_date
FROM orders 
GROUP BY `Customer Name`;

-- Now safe UPDATE (join on temp)
ALTER TABLE orders ADD COLUMN customer_recency INT;

UPDATE orders o
JOIN customer_last_order clo ON o.`Customer Name` = clo.`Customer Name`
SET o.customer_recency = DATEDIFF(clo.last_order_date, o.`Order Date`);

-- Verify
SELECT `Customer Name`, MAX(customer_recency) AS days_since_last 
FROM orders 
GROUP BY `Customer Name` 
ORDER BY days_since_last DESC 
LIMIT 10;

DROP TEMPORARY TABLE customer_last_order;

-- Verify new features
SELECT 
    ROUND(AVG(profit_margin), 2) AS avg_margin_pct,
    MIN(profit_margin) AS min_margin,
    MAX(profit_margin) AS max_margin,
    COUNT(DISTINCT order_year) AS unique_years
FROM orders;

-- ==============================================
-- Phase 4: Univariate Analysis
-- ==============================================
-- Numeric summary with approx quartiles
WITH sales_stats AS (
    SELECT Sales,
           NTILE(4) OVER (ORDER BY Sales) AS quartile
    FROM orders
)
SELECT 
    ROUND(MIN(Sales), 2) AS min_sales,
    ROUND(MAX(CASE WHEN quartile = 1 THEN Sales END), 2) AS q1_sales,
    ROUND(AVG(Sales), 2) AS avg_sales,
    ROUND(MAX(CASE WHEN quartile = 3 THEN Sales END), 2) AS q3_sales,
    ROUND(MAX(Sales), 2) AS max_sales,
    ROUND(STD(Sales), 2) AS std_sales
FROM sales_stats;

-- Quick approx quartiles
WITH sales_stats AS (
    SELECT Sales,
           NTILE(4) OVER (ORDER BY Sales) AS quartile
    FROM orders
)
SELECT 
    ROUND(MIN(Sales), 2) AS min_sales,
    ROUND(MAX(CASE WHEN quartile = 1 THEN Sales END), 2) AS q1_sales,
    ROUND(AVG(Sales), 2) AS avg_sales,
    ROUND(MAX(CASE WHEN quartile = 3 THEN Sales END), 2) AS q3_sales,
    ROUND(MAX(Sales), 2) AS max_sales,
    ROUND(STDDEV(Sales), 2) AS std_sales
FROM sales_stats;

-- Profit margin distribution
SELECT 
    ROUND(profit_margin, 1) AS margin_bucket,
    COUNT(*) AS order_count,
    ROUND(AVG(Sales), 0) AS avg_order_value
FROM orders 
WHERE profit_margin IS NOT NULL
GROUP BY margin_bucket 
ORDER BY margin_bucket;

-- Category counts & avg sales
SELECT 
    Category,
    COUNT(*) AS order_count,
    ROUND(SUM(Sales), 0) AS total_sales,
    ROUND(AVG(Sales), 0) AS avg_order_size,
    ROUND(AVG(profit_margin), 1) AS avg_margin_pct
FROM orders 
GROUP BY Category 
ORDER BY order_count DESC;

-- Region & City top
SELECT Region, COUNT(*) AS orders, ROUND(SUM(Sales), 0) AS total_sales FROM orders GROUP BY Region ORDER BY orders DESC;
SELECT City, COUNT(*) AS orders FROM orders GROUP BY City ORDER BY orders DESC LIMIT 10;

-- Orders by year/month
SELECT 
    order_year,
    order_month,
    COUNT(*) AS monthly_orders,
    ROUND(SUM(Sales), 0) AS monthly_sales
FROM orders 
GROUP BY order_year, order_month 
ORDER BY order_year, order_month;

-- ========================================
-- Phase 5: Bivariate Analysis
-- ========================================
-- 5.1. Category vs Avg Sales/Profit Margin/Orders
SELECT 
    Category,
    COUNT(*) AS order_count,
    ROUND(AVG(Sales), 0) AS avg_sales,
    ROUND(AVG(profit_margin), 1) AS avg_margin_pct,
    ROUND(SUM(Profit), 0) AS total_profit
FROM orders 
GROUP BY Category 
ORDER BY total_profit DESC;

-- 5.2. Region vs Performance
SELECT 
    Region,
    COUNT(*) AS orders,
    ROUND(SUM(Sales), 0) AS total_sales,
    ROUND(AVG(profit_margin), 1) AS avg_margin,
    ROUND(SUM(Profit), 0) AS total_profit
FROM orders 
GROUP BY Region 
ORDER BY total_profit DESC;

-- 5.3. Discount Buckets vs Margin
SELECT 
    FLOOR(Discount * 10)/10 AS discount_bucket,  -- 0.0 to 0.4
    COUNT(*) AS orders,
    ROUND(AVG(profit_margin), 1) AS avg_margin_pct,
    ROUND(MIN(profit_margin), 1) AS min_margin,
    ROUND(MAX(profit_margin), 1) AS max_margin
FROM orders 
GROUP BY discount_bucket 
ORDER BY discount_bucket;

-- 5.4. Time trends: Year vs Monthly Sales Growth
SELECT 
    order_year,
    COUNT(*) AS yearly_orders,
    ROUND(SUM(Sales), 0) AS yearly_sales,
    ROUND(SUM(Sales) / NULLIF(LAG(SUM(Sales)) OVER (ORDER BY order_year), 0) * 100, 1) AS sales_growth_pct
FROM orders 
GROUP BY order_year 
ORDER BY order_year;

-- 5.5. City vs Avg Order Value (top 10)
SELECT 
    City,
    COUNT(*) AS orders,
    ROUND(AVG(Sales), 0) AS avg_order_value,
    ROUND(AVG(profit_margin), 1) AS avg_margin
FROM orders 
GROUP BY City 
ORDER BY avg_order_value DESC 
LIMIT 10;

-- ==========================================
-- Phase 6: Top Performers
-- ==========================================
-- 6.1. Top 10 Customers (Lifetime Value: Total Profit)
SELECT 
    `Customer Name`,
    COUNT(*) AS num_orders,
    ROUND(SUM(Sales), 0) AS total_sales,
    ROUND(SUM(Profit), 0) AS total_profit,
    ROUND(AVG(profit_margin), 1) AS avg_margin_pct
FROM orders 
GROUP BY `Customer Name`
ORDER BY total_profit DESC 
LIMIT 10;

-- 6.2. Top 5 Cities by Sales Volume/Value
SELECT 
    City,
    COUNT(*) AS orders,
    ROUND(SUM(Sales), 0) AS total_sales,
    ROUND(AVG(Sales), 0) AS avg_order_value
FROM orders 
GROUP BY City 
ORDER BY total_sales DESC 
LIMIT 5;

-- 6.3. Top 5 Sub Categories by Margin (≥10 orders)
SELECT 
    `Sub Category`,
    COUNT(*) AS orders,
    ROUND(AVG(profit_margin), 2) AS avg_margin_pct,
    ROUND(SUM(Profit), 0) AS total_profit
FROM orders 
GROUP BY `Sub Category` 
HAVING orders >= 10 
ORDER BY avg_margin_pct DESC 
LIMIT 5;

-- 6.4. Loyal/Recent Customers: Top 5 Active Customers (low recency + high value)
SELECT 
    `Customer Name`,
    COUNT(*) AS lifetime_orders,
    ROUND(SUM(Sales), 0) AS lifetime_value,
    MAX(customer_recency) AS days_since_last_order
FROM orders 
GROUP BY `Customer Name` 
HAVING lifetime_orders >= 5 
ORDER BY days_since_last_order ASC, lifetime_value DESC 
LIMIT 5;

-- 6.5. Profit Leakage: Which Sub Categories have profit_margin < 10% despite high sales volume? (Low-margin traps)
-- Margin health check
SELECT 
    ROUND(AVG(profit_margin), 1) AS avg_margin_all,
    ROUND(MIN(profit_margin), 1) AS worst_single_order,
    COUNT(*) AS orders_below_12pct
FROM orders 
WHERE profit_margin < 12;

-- Flag worst 5 Sub Categories by margin (regardless of sales)
SELECT 
    `Sub Category`,
    COUNT(*) AS orders,
    ROUND(AVG(profit_margin), 1) AS avg_margin,
    ROUND(SUM(Sales), 0) AS total_sales
FROM orders 
GROUP BY `Sub Category` 
ORDER BY avg_margin ASC 
LIMIT 5;

-- Discount Erosion: Buckets of Discount where avg profit_margin drops >20% from overall avg? (Optimal discount threshold)
SELECT ROUND(AVG(profit_margin), 1) AS overall_avg_margin FROM orders;

SELECT 
	discount_bucket, 
    ROUND(AVG(profit_margin), 1) AS avg_margin, 
    COUNT(*) AS orders
FROM (SELECT FLOOR(Discount * 10)/10 AS discount_bucket, profit_margin FROM orders) t 
GROUP BY discount_bucket 
ORDER BY discount_bucket;

-- Lowest margins (shows reality)
SELECT 
    `Sub Category`,
    ROUND(AVG(profit_margin), 2) AS avg_margin_pct,
    COUNT(*) AS orders,
    ROUND(SUM(Sales), 0) AS total_sales
FROM orders 
GROUP BY `Sub Category` 
ORDER BY avg_margin_pct ASC 
LIMIT 10;

-- Customer Churn Risk: Top 10 customers by total_profit who haven't ordered in >365 days (recency >365)
SELECT 
	`Customer Name`, 
    SUM(Profit) AS lifetime_profit, 
    MAX(customer_recency) AS days_since_last
FROM orders 
GROUP BY `Customer Name` 
HAVING days_since_last > 365 
ORDER BY lifetime_profit DESC 
LIMIT 10;

-- Seasonal Peaks: Month/year combos with sales >1.5x monthly avg (stock-up planning)
WITH monthly_avg AS (
    SELECT AVG(SUM_Sales) AS avg_monthly_sales
    FROM (SELECT order_month, SUM(Sales) AS SUM_Sales FROM orders GROUP BY order_year, order_month) t
)
SELECT order_year, order_month, SUM(Sales) AS monthly_sales,
       ROUND(SUM(Sales) / (SELECT avg_monthly_sales FROM monthly_avg) * 100, 1) AS pct_above_avg
FROM orders 
GROUP BY order_year, order_month 
HAVING SUM(Sales) > 1.5 * (SELECT avg_monthly_sales FROM monthly_avg)
ORDER BY monthly_sales DESC;

-- Region Imbalance: Regions with high orders but low profit/region (underperforming areas).
SELECT 
	Region, COUNT(*) AS orders, 
	SUM(Profit) AS total_profit, 
    ROUND(SUM(Profit)/COUNT(*), 0) AS profit_per_order
FROM orders 
GROUP BY Region 
ORDER BY orders DESC;

-- Whale Orders: Single orders >₹2000 sales (VIP handling needed?).
SELECT 
	`Order ID`, 	
    `Customer Name`, 
    City, Sales, 
    profit_margin, 
    Category
FROM orders 
WHERE Sales > 2000 
ORDER BY Sales DESC 
LIMIT 20;

-- Margin Stars: Sub Categories with top 5 avg profit_margin AND >₹500k total sales (double-down products)
SELECT 
	`Sub Category`, 
    AVG(profit_margin) AS avg_margin, 
    SUM(Sales) AS total_sales
FROM orders 
GROUP BY `Sub Category` 
HAVING total_sales > 500000 
ORDER BY avg_margin DESC 
LIMIT 5;

-- ==========================================
-- Phase 7: Business Insights
-- ==========================================
-- 7.1. Executive Summary
SELECT 
    COUNT(*) AS total_orders,
    COUNT(DISTINCT `Customer Name`) AS active_customers,
    ROUND(SUM(Sales), 0) AS total_revenue,
    ROUND(SUM(Profit), 0) AS total_profit,
    ROUND(AVG(profit_margin), 1) AS avg_profit_margin_pct,
    ROUND(AVG(Sales), 0) AS avg_order_value
FROM orders;

-- Revenue Growth & Seasonality
-- YoY Growth + Peak Months
WITH yearly AS (
    SELECT 
        order_year,
        SUM(Sales) AS yearly_sales,
        SUM(Profit) AS yearly_profit
    FROM orders GROUP BY order_year
)
SELECT 
    order_year,
    yearly_sales,
    ROUND(yearly_sales / LAG(yearly_sales) OVER (ORDER BY order_year) * 100 - 100, 1) AS growth_pct
FROM yearly ORDER BY order_year;

-- Top 5 Peak Months
SELECT 
    order_month,
    COUNT(*) AS peak_orders,
    ROUND(SUM(Sales), 0) AS peak_sales
FROM orders 
GROUP BY order_month 
ORDER BY peak_sales DESC 
LIMIT 5;

-- Category Strategy
-- Stars: High Profit/High Sales | Question Marks: High Sales/Low Profit
SELECT 
    Category,
    ROUND(SUM(Sales), 0) AS total_sales,
    ROUND(SUM(Profit), 0) AS total_profit,
    ROUND(AVG(profit_margin), 1) AS margin_pct,
    CASE 
        WHEN SUM(Sales) > 2000000 AND AVG(profit_margin) > 20 THEN 'Star Category'
        WHEN SUM(Sales) > 2000000 THEN 'Investigate (Low Margin)'
        WHEN AVG(profit_margin) > 25 THEN 'Promote (High Margin)'
        ELSE 'Maintain'
    END AS strategy
FROM orders 
GROUP BY Category 
ORDER BY total_profit DESC;

-- Discount Optimization
SELECT 
    FLOOR(Discount * 10)/10 AS discount_range,
    AVG(profit_margin) AS avg_margin,
    AVG(Sales) AS avg_ticket,
    COUNT(*) AS orders
FROM orders 
GROUP BY discount_range 
ORDER BY discount_range;

-- Customer Segmentation: RFM: Recency (days since last), Frequency (orders), Monetary (sales)
SELECT 
    CASE 
        WHEN MAX(customer_recency) <= 180 THEN 'Recent'
        WHEN MAX(customer_recency) <= 365 THEN 'At Risk' 
        ELSE 'Churned'
    END AS recency_segment,
    COUNT(*) AS frequency,
    ROUND(SUM(Sales), 0) AS monetary,
    COUNT(*) AS customers
FROM orders 
GROUP BY `Customer Name`
HAVING frequency >= 1
ORDER BY monetary DESC;

-- Geo Focus: Top Cities Opportunity Score (Sales * Margin)
SELECT 
    City,
    ROUND(SUM(Sales), 0) AS city_sales,
    ROUND(AVG(profit_margin), 1) AS city_margin,
    ROUND(SUM(Sales * profit_margin / 100), 0) AS profit_potential
FROM orders 
GROUP BY City 
ORDER BY profit_potential DESC 
LIMIT 10;

-- =========================================
-- Phase 8: Export Pipeline
-- =========================================
-- 8.1. Master Dashboard
SELECT 'KPIs' AS Sheet, 'Overall' AS Subcat,
       ROUND(SUM(Sales)/100000,1) AS Revenue_Cr,
       ROUND(SUM(Profit)/100000,1) AS Profit_Lacs,
       ROUND(AVG(profit_margin),1) AS Margin_Pct,
       COUNT(*) AS Orders
FROM orders

UNION ALL

SELECT *
FROM (
    SELECT 'Top_Customers' AS Sheet,
           `Customer Name` AS Subcat,
           ROUND(SUM(Sales)/1000,0) AS Revenue_Cr,
           ROUND(SUM(Profit)/1000,0) AS Profit_Lacs,
           ROUND(AVG(profit_margin),1) AS Margin_Pct,
           COUNT(*) AS Orders
    FROM orders
    GROUP BY `Customer Name`
    ORDER BY SUM(Profit) DESC
    LIMIT 10
) t1

UNION ALL

SELECT *
FROM (
    SELECT 'Top_Categories' AS Sheet,
           Category AS Subcat,
           ROUND(SUM(Sales)/1000,0),
           ROUND(SUM(Profit)/1000,0),
           ROUND(AVG(profit_margin),1),
           COUNT(*)
    FROM orders
    GROUP BY Category
    ORDER BY SUM(Profit) DESC
    LIMIT 7
) t2

UNION ALL

SELECT *
FROM (
    SELECT 'Top_Cities' AS Sheet,
           City AS Subcat,
           ROUND(SUM(Sales)/1000,0),
           ROUND(SUM(Profit)/1000,0),
           ROUND(AVG(profit_margin),1),
           COUNT(*)
    FROM orders
    GROUP BY City
    ORDER BY SUM(Profit) DESC
    LIMIT 10
) t3;

-- 8.2. Time Series for Charts
SELECT 
    order_year AS Year,
    order_month AS Month,
    COUNT(*) AS Orders,
    ROUND(SUM(Sales), 0) AS Sales,
    ROUND(SUM(Profit), 0) AS Profit
FROM orders 
GROUP BY order_year, order_month 
ORDER BY order_year, order_month;

-- 8.3. RFM Customers (For Win-back)
SELECT 
    `Customer Name`,
    COUNT(*) AS Frequency,
    ROUND(SUM(Sales), 0) AS Monetary,
    MAX(customer_recency) AS Recency_Days,
    CASE 
        WHEN MAX(customer_recency) > 365 THEN 'Churn - Re-engage'
        WHEN COUNT(*) > 10 THEN 'VIP - Upsell'
        ELSE 'Standard'
    END AS Segment
FROM orders 
GROUP BY `Customer Name` 
ORDER BY Monetary DESC;

-- City Margin = (Total Profit / Total Sales) * 100 per City
SELECT 
    City,
    ROUND(SUM(Sales), 0) AS 'Citywise Sales',
    ROUND(SUM(Profit), 0) AS 'Citywise Profit',
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 1) AS 'Margin %',
    COUNT(*) AS 'Total Orders',
    ROUND(SUM(Sales * Profit / 100), 0) AS profit_potential  -- Bonus: Weighted
FROM orders 
GROUP BY City 
ORDER BY 'Citywise Profit' DESC;

-- Profit Potential = (Best Margin - City Margin) × City Sales
WITH city_metrics AS (
    SELECT 
        City,
        SUM(Sales) AS city_sales,
        SUM(Profit) AS city_profit,
        SUM(Profit) / NULLIF(SUM(Sales), 0) * 100 AS city_margin_pct
    FROM orders 
    GROUP BY City
),
best_margin AS (
    SELECT MAX(city_margin_pct) AS best_city_margin
    FROM city_metrics
)
SELECT 
    cm.City,
    ROUND(cm.city_sales, 0) AS city_sales,
    ROUND(cm.city_margin_pct, 1) AS city_margin_pct,
    ROUND(bm.best_city_margin - cm.city_margin_pct, 1) AS margin_gap_pct,
    ROUND((bm.best_city_margin - cm.city_margin_pct) / 100 * cm.city_sales, 0) AS profit_potential,
    cm.city_profit
FROM city_metrics cm
CROSS JOIN best_margin bm
ORDER BY profit_potential DESC;







