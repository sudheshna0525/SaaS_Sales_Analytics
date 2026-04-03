Status: Completed
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

-- Revenue concentration among top customers to assess dependency risk --

DROP VIEW IF EXISTS customer_dependency_risk;

CREATE VIEW customer_dependency_risk AS

WITH customer_revenue AS
                        (
                         SELECT 
                               cu.customer_id as cust_id,
				                       cu.customer_name as cust_name,
							                 SUM(sales) as total_revenue
					               FROM fact_sales as fs
							           JOIN dim_customer as cu ON cu.customer_id = fs.customer_id
							           GROUP BY cu.customer_id, cu.customer_name
						            ),
customer_dependency AS
						         (
						          SELECT
							              cust_id,
								            cust_name,
							              total_revenue,
								            SUM(total_revenue) Over(ORDER BY total_revenue DESC) as running_total_revenue,
								            SUM(total_revenue) OVER() as overall_revenue
						          FROM customer_revenue
                      )
SELECT
      cust_id,
	    cust_name,
	    total_revenue,
	    running_total_revenue,
	    overall_revenue,
	    ROUND((total_revenue)*100/overall_revenue,2) as customer_revenue_contribution,
	    ROUND((running_total_revenue)*100/overall_revenue,2) as revenue_concentration
FROM customer_dependency;	

-- Customer Category Based on Purchase Frequency and Margin --

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
base_frequency AS
                 (
				          SELECT
				                cust_id,
						            cust_name,
						            profit_loss,
						            revenue,
						            days_as_customer,
						            unique_orders,
                        ROUND(AVG(days_as_customer/NULLIF((unique_orders - 1),0)) OVER(),0) AS base_frequency
                   FROM customer_orders
				          ),
customer_frequency AS
                     (
					            SELECT
                            cust_id,
	                          cust_name,
							              ROUND((profit_loss*100)/revenue,2) as margin,
							              base_frequency,
	                          ROUND(days_as_customer/NULLIF((unique_orders - 1),0),0) as cust_order_frequency  
                     FROM base_frequency
                     ORDER BY cust_order_frequency 
					          ),
customer_margin AS
                  (
                   SELECT
	                     percentile_cont(0.5) WITHIN GROUP(ORDER BY margin) as median_margin
					         FROM customer_frequency
				          )
SELECT 
      cust_id,
	    cust_name,
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
FROM customer_frequency
CROSS JOIN customer_margin;


-- Revenue driving product and segment --

DROP VIEW IF EXISTS product_revenue_driver;

CREATE VIEW product_revenue AS

WITH product_revenue AS
                        (
                         SELECT
                               dp.product_id as prod_id,
				                       dp.product_name as prod_name,
							                 SUM(sales) as total_revenue
					              FROM fact_sales as fs
							          JOIN dim_product as dp ON dp.product_id = fs.product_id
							          GROUP BY dp.product_id, dp.product_name
						            ),
product_driver AS
						  (
						   SELECT
							       prod_id,
								     prod_name,
							       total_revenue,
								     SUM(total_revenue) Over(ORDER BY total_revenue DESC) as running_total_revenue,
								     SUM(total_revenue) OVER() as overall_revenue
						   FROM product_revenue
              ),
SELECT
      prod_id,
	    prod_name,
	    total_revenue,
	    running_total_revenue,
	    overall_revenue,
	    ROUND((total_revenue)*100/overall_revenue,2) as product_revenue_contribution,
	    ROUND((running_total_revenue)*100/overall_revenue,2) as revenue_concentration
FROM product_driver;					
	  	  
-- Product categorization based on volume and margin --

DROP VIEW IF EXISTS product_categorization;

CREATE VIEW product_categorization AS

With product_volume_margin as 
                             (
							                SELECT 
							                      dp.product_id as product_id,
									                  dp.product_name as product_name,
									                  COUNT(DISTINCT(order_id)) as volume,
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
					          )
SELECT 
      product_id,
	    product_name,
	    volume,
	    median_volume,
	    margin,
	    median_margin,
	    avg_discount,
	    CASE
	        WHEN volume > median_volume and margin > median_margin THEN 'High Volume, High Margin'
	        WHEN volume > median_volume and margin < median_margin THEN 'High Volume, Low Margin'
		      WHEN volume < median_volume and margin > median_margin THEN 'Low Volume, High Margin'			
          WHEN volume < median_volume and margin < median_margin THEN 'Low Volume, Low Margin'
      End as product_quadrants
FROM volume_margin_avg
CROSS JOIN product_volume_margin as pvm
ORDER BY product_quadrants;

-- Discount Categorization --

DROP VIEW IF EXISTS Discount_Table;

CREATE VIEW Discount_Table AS

SELECT
      *,
      CASE
	        WHEN discount = 0 THEN 'No Discount'
		      WHEN discount > 0 AND discount <= 0.20 THEN '1-20%'
          WHEN discount > 0.20 AND discount <= 0.40 THEN'21-40%'
          WHEN discount > 0.40 AND discount <= 0.60 THEN '41-60%'
          WHEN discount > 0.60 AND discount <= 0.80 THEN '61-80%'
          ELSE '81-100%'
      END as disc_bucket
FROM fact_sales;

SELECT * FROM Discount_Table;
				   
-- How frequently products are sold with discounting --

SELECT
	  COUNT(order_id) as zero_disc_orders,
	  (SELECT COUNT(order_id) FROM fact_sales) as total_orders,
	  ROUND((COUNT(order_id)*100.00)/(SELECT COUNT(order_id) FROM fact_sales),2) AS percentage_orders
FROM fact_sales
WHERE discount > 0 ;

-- Is higher discounting driving more orders --

SELECT
      disc_bucket,
	  COUNT(distinct product_id),
      COUNT(ORDER_ID) as orders_count
FROM DISCOUNT_TABLE
GROUP BY disc_bucket
ORDER BY orders_count DESC;

-- Products with high discounting --

SELECT
      dp.product_id,
	  dp.product_name,
	  ROUND(AVG(discount)*100,2) as avg_discount,
	  count(order_id) as number_orders,
	  SUM(sales) as revenue
FROM discount_table as dt
JOIN dim_product as dp ON dp.product_id = dt.product_id
GROUP BY dp.product_id,dp.product_name
ORDER BY avg_discount DESC;
