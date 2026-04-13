---------------- Data Validation ------------------

--  Null and Blank Values --

SELECT 
COUNT(*) FILTER ( 
                 WHERE
                      order_id IS NULL OR order_id = ' '
                      OR
                      sales_rep IS NULL OR sales_rep = ' '
                      OR
                      customer_id IS NULL
                      OR
                      sales IS NULL
                      OR
                      Quantity IS NULL
                      OR
                      Discount IS NULL
                      OR
                      Profit_Loss IS NULL
                 ) 
FROM SaaS_Sales_Analysis;

-- Checking for Row Duplicates --

SELECT 
     COUNT(*) 
FROM SaaS_Sales_Analysis;


SELECT * 
FROM (
      SELECT
           ROW_NUMBER() OVER(PARTITION BY order_id,product,sales,sales_rep,license ORDER BY Order_Date) as Rank, *
      FROM SaaS_Sales_Analysis
      )
WHERE Rank >1;

-- Date and Date key alignment--

SELECT * 
FROM SaaS_Sales_Analysis
WHERE CAST(date_key as text) != TO_CHAR(order_date, 'YYYYMMDD');

-- Range Validation for Quanitative Data (Quantity, Sales and Profit, Discount) --
		
-- Quantity

SELECT Quantity 
From SaaS_Sales_Analysis
WHERE Quantity < 0;

-- Discount

Select Discount 
FROM SaaS_Sales_Analysis
WHERE (DISCOUNT NOT BETWEEN 0 AND 1) OR DISCOUNT <0;

-- Sales

SELECT sales 
FROM SaaS_Sales_Analysis
WHERE Sales <= 0;

-- Profit

SELECT Profit_loss 
FROM SaaS_Sales_Analysis
WHERE Profit_loss > Sales 

-- Categorical Data Check (checking for casing and misspelling) --

SELECT 
     DISTINCT Segment AS segment_list 
FROM SaaS_Sales_Analysis;

SELECT 
     DISTINCT Industry AS Industry_list 
FROM SaaS_Sales_Analysis;

SELECT 
     DISTINCT Product as product_list 
FROM SaaS_Sales_Analysis; 

SELECT 
      DISTINCT Region as region_list 
FROM SaaS_Sales_Analysis;

SELECT 
     DISTINCT Subregion as subregion_list 
FROM SaaS_Sales_Analysis;

----------------  Data Modeling ------------------ 

-- Star Schema Design Overview -- 

SELECT * FROM SaaS_Sales_Analysis;

-- Flat staging table of SaaS_Sales_Analysis is normalized into star schema --
        
-- Dim_Customer --   

DROP TABLE IF EXISTS dim_customer; 

CREATE TABLE dim_customer
                         (
	                      customer_id INT PRIMARY KEY,
						  customer_name VARCHAR(30),
						  industry VARCHAR(17)
						  );

INSERT INTO dim_customer 
                     (customer_id, customer_name, industry)
    	 SELECT DISTINCT(customer_id), customer, industry 
         FROM SaaS_Sales_Analysis;

-- Dim_Customer Check --

SELECT * FROM dim_customer;

SELECT 
     COUNT(*),
	 COUNT(DISTINCT customer_name) as unique_customer_name,
	 COUNT(DISTINCT customer_id) as unique_customer_id
From dim_customer;
				
-- Dim_Product --

DROP TABLE IF EXISTS dim_product;

CREATE SEQUENCE product_id_seq START 100;

CREATE TABLE dim_product
                        (
                          product_id INT PRIMARY KEY,
						  product_name VARCHAR(50)
						);

INSERT INTO dim_product 
                   (product_id, product_name)			  
     SELECT nextval('product_id_seq'),
	        product
	 FROM
	     (
		 SELECT DISTINCT(Product) as product
         FROM SaaS_Sales_Analysis
		 ) As products;

-- Dim_product check

SELECT * FROM dim_product;

SELECT 
     COUNT(*),
	 COUNT(DISTINCT product_name) as unique_product_name
From dim_product;
	   
-- Dim_Geography -- 

SELECT DISTINCT region FROM SaaS_Sales_Analysis;
SELECT DISTINCT subregion FROM SaaS_Sales_Analysis;
SELECT DISTINCT country FROM SaaS_Sales_Analysis;
SELECT DISTINCT city FROM SaaS_Sales_Analysis;

-- Region

DROP TABLE IF EXISTS regions;

CREATE TABLE regions
                    (
                     id SERIAL PRIMARY KEY,
					 region VARCHAR(50)
					);

INSERT INTO regions 
                  (region)
                  (
				   SELECT DISTINCT region 
				   FROM SaaS_Sales_Analysis
				   );

SELECT * FROM regions;

-- Subregion

DROP TABLE IF EXISTS subregions;

CREATE TABLE subregions
                    (
                     id SERIAL PRIMARY KEY,
					 subregion VARCHAR(50),
                     region_id INT REFERENCES regions(id)
					);
					
INSERT INTO subregions 
                  (subregion, region_id)
                  (
				   SELECT DISTINCT subregion,
	                               regions.id
	               FROM SaaS_Sales_Analysis
	               INNER JOIN regions 
                   ON regions.region = saas_sales_analysis.region
                  );

SELECT * FROM subregions;	

--  Country

DROP TABLE IF EXISTS countries;

CREATE TABLE countries
                    (
                     id SERIAL PRIMARY KEY,
					 country VARCHAR(50),
                     sub_region_id INT REFERENCES subregions(id)
					);

INSERT INTO countries 
                  (country, sub_region_id)
                  (
				   SELECT DISTINCT country,
	                               subregions.id
	               FROM SaaS_Sales_Analysis
	               INNER JOIN subregions 
                   ON subregions.subregion = saas_sales_analysis.subregion
                  );

SELECT * FROM countries

--  City

DROP TABLE IF EXISTS cities;

CREATE TABLE cities
                    (
                     id SERIAL PRIMARY KEY,
					 city VARCHAR(50),
                     country_id INT REFERENCES countries(id)
					);

INSERT INTO cities 
                  (city, country_id)
                  (
				   SELECT DISTINCT city,
	                               countries.id
	               FROM SaaS_Sales_Analysis
	               INNER JOIN countries 
                   ON countries.country = saas_sales_analysis.country
                  );

SELECT * FROM cities;

--- Regions, subregions, countries, cities in one table

DROP VIEW IF EXISTS dim_geography;

CREATE VIEW  dim_geography AS
                             SELECT
							      cities.id as geography_id,
	                              cities.city,
								  countries.id as country_id,
	                              countries.country,
								  subregions.id as subregion_id,
	                              subregions.subregion,
								  regions.id as region_id,
                                  regions.region
                             FROM cities
                             JOIN countries ON countries.id = cities.country_id
                             JOIN subregions ON subregions.id = countries.sub_region_id
                             JOIN regions ON regions.id = subregions.region_id
                             ORDER BY city, country,subregion,region;
-- Dim_geography check

SELECT * FROM dim_geography;

-- Dim_Date --         

DROP TABLE IF EXISTS dim_date;

CREATE TABLE dim_date
                    (
                     date_id INT PRIMARY KEY,
					 full_date DATE,
					 year INT,
					 quarter INT,
					 month INT,
					 month_name VARCHAR(40),
					 week INT,
					 week_day VARCHAR(40),
					 is_weekend BOOLEAN
					);

INSERT INTO dim_date 
                    (
					 date_id,
					 full_date,
					 year,
					 quarter,
					 month,
					 month_name,
					 week,
					 week_day,
					 is_weekend
					)
               (
                SELECT    
			         TO_CHAR(ref_date, 'YYYYMMDD')::int AS date_id,
			         ref_date::DATE AS full_date,
			         EXTRACT(YEAR FROM ref_date)::INT as Year,
			         EXTRACT(Quarter FROM ref_date)::INT as Quarter,
			         EXTRACT(Month FROM ref_date)::INT as Month,
			         TO_CHAR(ref_date, 'Month') as month_name,
			         EXTRACT(WEEK FROM ref_date)::INT as week,
			         TO_CHAR(ref_date, 'Day') as week_day,
			         EXTRACT(DOW FROM ref_date) IN(0,6) AS is_weekend 
			    FROM generate_series
				                    (
			                         (SELECT MIN(order_date)::DATE FROM SaaS_Sales_Analysis),
					                 (SELECT MAX(order_date)::DATE FROM SaaS_Sales_Analysis),
					                  '1 DAY'::INTERVAL
					                ) as ref_date
			   );

SELECT * FROM dim_date;


-- Fact_Sales --

SELECT * FROM SaaS_Sales_AnalysiS;

DROP TABLE IF EXISTS fact_sales;

CREATE TABLE fact_sales
                    (
                     row_sales_id INT PRIMARY KEY,
					 order_id VARCHAR(50),
					 date_id INT REFERENCES dim_date(date_id),
					 product_id INT REFERENCES dim_product(product_id),
					 customer_id INT REFERENCES dim_customer(customer_id),
					 geography_id INT REFERENCES cities(id),
					 contact_name VARCHAR(30),
					 segment VARCHAR(15),
					 license VARCHAR(15),
					 sales DECIMAL(10,2),
					 quantity int,
					 discount DECIMAL(5,4),
					 profit_or_loss DECIMAL (10,2)
					);

INSERT INTO fact_sales
                    (
                     row_sales_id,
					 order_id,
					 date_id,
					 product_id,
                     customer_id,
					 geography_id,
					 contact_name,
					 segment,
					 license,
					 sales,
					 quantity,
					 discount,
					 profit_or_loss
					)

					(
                     SELECT 
					       s.row_id,
						   s.order_id,
						   d.date_id,
						   p.product_id,
						   cu.customer_id,
						   c.id,
						   s.sales_rep,
						   s.segment,
						   s.license,
						   s.sales,
						   s.quantity,
						   s.discount,
						   s.profit_loss
					FROM SaaS_Sales_Analysis as s
					JOIN dim_date as d ON s.order_date = d.full_date
					JOIN dim_product as p ON s.product = p.product_name
					JOIN dim_customer as cu ON s.customer_id = cu.customer_id
					JOIN cities as c ON s.city = c.city
					);

-- Fact_sales Check

SELECT COUNT(*) FROM fact_sales;

SELECT COUNT(*) FROM SaaS_Sales_Analysis;



----------------   Business Analysis  ------------------

-- 	Analyzing revenue, profit, and margin trends YoY to assess overall business performance --

SELECT
      dd.year as year,
      SUM(sales) as revenue,
	  SUM(profit_or_loss) as profit,
	  ROUND(sum(profit_or_loss)*100/sum(sales),2) as YoY_profit_margin
FROM fact_sales as fs
JOIN dim_date as dd ON dd.date_id = fs.date_id
GROUP BY year
ORDER BY year;

-- Periods that consistently generate the highest revenue --

-- Quarterly

WITH quarterly_rank AS
                    (
                     SELECT 
                           dd.year as year,
	                       dd.quarter as quarter,
	                       sum(sales) as revenue,
	                       RANK() OVER(PARTITION BY dd.year ORDER BY sum(sales) DESC) as revenue_rank_quarterly
                      FROM fact_sales as fs
                      JOIN dim_date as dd ON dd.date_id = fs.date_id
                      GROUP BY dd.year, dd.quarter
					  )
SELECT 
      quarter,
	  COUNT(CASE WHEN revenue_rank_quarterly = 1 THEN 1 END) AS top_quarter,
	  COUNT(CASE WHEN revenue_rank_quarterly = 4 THEN 1 END) AS bottom_quarter,
	  ROUND(Avg(revenue),2) as avg_revenue
FROM quarterly_rank
GROUP BY quarter
ORDER BY top_quarter DESC;

-- Monthly 

WITH monthly_rank AS
                    (
                     SELECT 
                           dd.year as year,
	                       dd.month as month,
	                       sum(sales) as revenue,
	                       RANK() OVER(PARTITION BY dd.year ORDER BY sum(sales) DESC) as revenue_rank_monthly
                      FROM fact_sales as fs
                      JOIN dim_date as dd ON dd.date_id = fs.date_id
                      GROUP BY dd.year, dd.month
					  )
SELECT 
      month,
	  COUNT(CASE WHEN revenue_rank_monthly = 1 THEN 1 END) AS top_month,
	  COUNT(CASE WHEN revenue_rank_monthly = 4 THEN 1 END) AS bottom_month,
	  ROUND(Avg(revenue),2) as avg_revenue
FROM monthly_rank
GROUP BY month
ORDER BY top_month DESC;

-- Checking whether high-revenue periods are associated with low margin and vice versa --

WITH quarterly_metrics AS
                       (
                        SELECT
                              dd.year as year,
	                          dd.quarter as quarter,
	                          sum(sales) as revenue,
	                          ROUND(sum(profit_or_loss)*100/sum(sales),2) as margin,
							  RANK() OVER(PARTITION BY Year ORDER by SUM(sales) DESC) as revenue_rank
                        FROM fact_sales as fs
                        JOIN dim_date as dd ON dd.date_id = fs.date_id
                        GROUP BY dd.year, dd.quarter
                       )
SELECT 	
      year,
	  MAX(quarter) FILTER ( WHERE revenue_rank = 1) as high_revenue_quarter,
	  MAX(margin) FILTER ( WHERE revenue_rank = 1) as high_revenue_quarter_margin,
	  Max(quarter) FILTER ( WHERE revenue_rank = 4) as low_revenue_quarter,
	  MAX(margin) FILTER ( WHERE revenue_rank = 4) as low_revenue_quarter_margin
FROM quarterly_metrics
WHERE revenue_rank = 1 OR revenue_rank = 4 
GROUP BY YEAR
ORDER BY YEAR;


-- Revenue Distribution by profit and loss making orders -- 

SELECT
      CASE 
	      WHEN profit_or_loss > 0 THEN 'Profit'
	      WHEN profit_or_loss < 0 THEN 'Loss'
	      Else 'Break Even'
       END AS category,
	   SUM(sales) as total_revenue,
	   ROUND(SUM(sales)*100/SUM(SUM(sales)) OVER(),2) as revenue_contribution,
	   ROUND(AVG(discount)*100,2) as avg_discount,
	   SUM(profit_or_loss) as total_profit_loss,
	   ROUND(SUM(profit_or_loss)*100/SUM(sales),2) as margin,
	   COUNT(order_id) as total_orders	  
FROM fact_sales
GROUP BY category
ORDER BY total_orders DESC;

---- Discount Categorization ----

DROP VIEW IF EXISTS Discount_Table;

CREATE VIEW Discount_Table AS

SELECT
      order_id,
	  product_id,
	  customer_id,
	  date_id,
	  sales,
	  profit_or_loss,
	  discount,
	  ROUND(profit_or_loss*100/sales,2) as margin,
      CASE
	      WHEN discount = 0 THEN 'No Discount'
		  WHEN discount > 0.00 AND discount <= 0.20 THEN '1-20%'
          WHEN discount > 0.20 AND discount <= 0.40 THEN'21-40%'
          WHEN discount > 0.40 AND discount <= 0.60 THEN '41-60%'
          WHEN discount > 0.60 AND discount <= 1.00 THEN '61-100%'
      END as disc_bucket
FROM fact_sales;

-- Is higher discounting driving higher margin or eroding margin?--

SELECT
      disc_bucket,
	  SUM(sales) as revenue,
	  ROUND(SUM(profit_or_loss)*100/SUM(sales),2) AS margin,
	  COUNT(distinct product_id),
      COUNT(ORDER_ID) as orders_count
FROM DISCOUNT_TABLE
GROUP BY disc_bucket
ORDER BY margin DESC;

-- How frequently products are sold with discounting --

SELECT
	  COUNT(order_id) as zero_disc_orders,
	  (SELECT COUNT(order_id) FROM fact_sales) as total_orders,
	  ROUND((COUNT(order_id)*100.00)/(SELECT COUNT(order_id) FROM fact_sales),2) AS percentage_orders
FROM fact_sales
WHERE discount > 0;

-- Are high discounts specific to a product --

SELECT
	   dt.product_id,
	   dp.product_name,
	   disc_bucket,
	   ROUND(avg(discount)*100,2) as avg_discount,
	   sum(profit_or_loss) as profit_loss
FROM DISCOUNT_TABLE as dt
JOIN dim_product as dp ON dp.product_id = dt.product_id
GROUP BY disc_bucket,dt.product_id, dp.product_name
ORDER BY profit_loss

-- Customer Categorization Based on Purchase Frequency and Margin --

DROP VIEW IF EXISTS customer_categorization;

CREATE VIEW customer_categorization AS

WITH customer_orders AS
                       (
                        SELECT
                              cu.customer_id as cust_id,
	                          cu.customer_name as cust_name,
							  MIN(dd.full_date)::DATE as first_order,
							  MAX(dd.full_date)::DATE as last_order,
							  (MAX(dd.full_date) - MIN(dd.full_date))::numeric AS days_as_customer,
	                          COUNT(DISTINCT fs.order_id) as unique_orders,
							  SUM(Sales) as revenue,
							  SUM(profit_or_loss) as profit_loss
                        FROM fact_sales as fs
                        JOIN dim_customer as cu ON cu.customer_id = fs.customer_id
						JOIN dim_date as dd on dd.date_id = fs.date_id
                        GROUP BY cu.customer_id, cu.customer_name
                        ),
margin_frequency AS
                 (
				  SELECT
				        cust_id,
						cust_name,
						profit_loss,
						revenue,
						ROUND(profit_loss*100/revenue,2) as margin,
						SUM(revenue) Over(ORDER BY revenue DESC) as running_total_revenue,
						SUM(revenue) OVER() as overall_revenue,
						days_as_customer,
						unique_orders,
                        ROUND(AVG(days_as_customer/NULLIF((unique_orders - 1),0)) OVER(),0) AS base_frequency,
						ROUND(days_as_customer/NULLIF((unique_orders - 1),0),0) as cust_order_frequency  
                   FROM customer_orders
				   ),
customer_margin AS
                  (
                   SELECT
	                     percentile_cont(0.5) WITHIN GROUP(ORDER BY margin) as median_margin
					 FROM margin_frequency
				   )
SELECT 
      cust_id,
	  cust_name,
	  revenue,
	  running_total_revenue,
	  overall_revenue,
	  ROUND((revenue)*100/overall_revenue,2) as customer_revenue_contribution,
	  ROUND((running_total_revenue)*100/overall_revenue,2) as revenue_concentration,
	  margin,
	  median_margin,
      cust_order_frequency,
	  base_frequency,
	  CASE 
	      WHEN margin > median_margin AND cust_order_frequency > base_frequency THEN 'High Margin, High purchase frequency'
		  WHEN margin > median_margin AND cust_order_frequency < base_frequency THEN 'High Margin, Low purchase frequency'
		  WHEN margin < median_margin AND cust_order_frequency > base_frequency THEN 'Low Margin, High purchase frequency'
		  WHEN margin < median_margin AND cust_order_frequency < base_frequency THEN 'Low Margin, Low purchase frequency'
		  ELSE 'Exception'
	  END as customer_category
FROM margin_frequency
CROSS JOIN customer_margin;

-- Product categorization based on volume and margin --

DROP VIEW IF EXISTS product_categorization;

CREATE VIEW product_categorization AS

With product_volume_margin as 
                             (
							  SELECT 
							        dp.product_id as product_id,
									dp.product_name as product_name,
									COUNT(DISTINCT(order_id)) as volume,
									SUM(sales) as revenue,
									sum(profit_or_loss) as profit_loss,
									ROUND(SUM(Profit_or_loss)*100.00/SUM(Sales),2) as margin,
									ROUND(Avg(discount)*100,2) as avg_discount									
							   FROM fact_sales as fs
							   JOIN dim_product as dp ON dp.product_id = fs.product_id
							   GROUP BY dp.product_id, dp.product_name
							   ),
volume_margin_avg AS
                    (
                     SELECT
	                       percentile_cont(0.5) WITHIN GROUP(ORDER BY volume) as median_volume,
	                       percentile_cont(0.5) WITHIN GROUP(ORDER BY margin) as median_margin
					 FROM product_volume_margin
					 ),
product_driver AS
                 (
                  SELECT 
                        product_id,
	                    product_name,
						revenue,
	                    SUM(revenue) Over(ORDER BY revenue DESC) as running_total_revenue,
	                    SUM(revenue) OVER() as overall_revenue,
	                    volume,
	                    median_volume,
						profit_loss
	                    margin,
	                    median_margin,
	                    avg_discount,
	                    CASE
	                        WHEN volume > median_volume and margin > median_margin THEN 'High Volume, High Margin'
	                        WHEN volume > median_volume and margin < median_margin THEN 'High Volume, Low Margin'
		                    WHEN volume < median_volume and margin > median_margin THEN 'Low Volume, High Margin'			
                            WHEN volume < median_volume and margin < median_margin THEN 'Low Volume, Low Margin'
                        End as product_category
                  FROM volume_margin_avg
                  CROSS JOIN product_volume_margin as pvm
				  )
				  
SELECT *,
       ROUND((revenue)*100/overall_revenue,2) as product_revenue_contribution,
	   ROUND((running_total_revenue)*100/overall_revenue,2) as revenue_concentration
FROM product_driver;




