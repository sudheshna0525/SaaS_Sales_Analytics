Status: Completed
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
