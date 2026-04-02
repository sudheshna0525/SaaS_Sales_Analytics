Status: Completed
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
