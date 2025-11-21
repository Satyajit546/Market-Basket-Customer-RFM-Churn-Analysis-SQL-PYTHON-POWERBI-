-- Table 1: Customer (Dimension Table)
CREATE TABLE customer (
    CustomerID VARCHAR(200) PRIMARY KEY,
    Name VARCHAR(200) ,
    Gender VARCHAR(200) ,
    Age INTEGER,
    City VARCHAR(200) ,
    SignupDate VARCHAR(100) 
);

-- Table 2: Product (Dimension Table)
CREATE TABLE product (
    ProductID VARCHAR(100) PRIMARY KEY,
    ProductName VARCHAR(500) ,
    Category VARCHAR(500) ,
    UnitPrice_INR DECIMAL(10,2),
    Brand VARCHAR(100) 
);

-- Table 3: Order (Fact/Bridge Table)
CREATE TABLE orders (
    OrderID VARCHAR(100)  PRIMARY KEY,
    CustomerID VARCHAR(100) ,
    OrderDate VARCHAR(100) ,
    Channel VARCHAR(100) ,
    PaymentMode VARCHAR(100) ,
    -- Foreign Key Constraint
    FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
);

-- Table 4: OrderDetails (Fact Table - Line Items)
CREATE TABLE OrderDetails (
    DetailID VARCHAR(100)  PRIMARY KEY,
    OrderID VARCHAR(100) ,
    ProductID VARCHAR(500) ,
    Quantity INTEGER,
    LineTotal_INR DECIMAL(10,2),
    -- Foreign Key Constraints
    FOREIGN KEY (OrderID) REFERENCES orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Product(ProductID)
);


-- Business Problem 1: Purchasing Patterns (Demographics & Region)
-- A. Average Order Value (AOV) by City and Gender. Shows how purchasing power varies across demographics and regions.
SELECT
    C.City,
    C.Gender,
    COUNT(DISTINCT O.OrderID) AS Total_Orders,
    SUM(OD.LineTotal_INR) / COUNT(DISTINCT O.OrderID) AS Avg_Order_Value_INR
FROM Customer C
JOIN Orders O ON C.CustomerID = O.CustomerID
JOIN OrderDetails OD ON O.OrderID = OD.OrderID
GROUP BY 1, 2
ORDER BY Avg_Order_Value_INR DESC;

-- B. Total Sales and Customer Count by Product Category. Identifies which categories are driving the most revenue and attracting the most customers.

SELECT
    P.Category,
    COUNT(DISTINCT C.CustomerID) AS Unique_Customers,
    SUM(OD.LineTotal_INR) AS Total_Revenue_INR
FROM orderdetails OD
JOIN product P ON OD.ProductID = P.ProductID
JOIN orders O ON OD.OrderID = O.OrderID
JOIN customer C ON O.CustomerID = C.CustomerID
GROUP BY 1
ORDER BY Total_Revenue_INR DESC;

 -- Business Problem 2: High-Value Customer Identification & Profitability (CLV)
 -- A. Identification of High-Value Customers (Top 10% by Revenue). Directly answers who should be targeted for loyalty campaigns.

WITH CustomerRevenue AS (
    -- Calculate total revenue for each customer
    SELECT
        C.CustomerID,
        C.Name,
        SUM(OD.LineTotal_INR) AS Total_Revenue,
        -- Calculate the decile (10 groups) the customer falls into
        NTILE(10) OVER (ORDER BY SUM(OD.LineTotal_INR) DESC) AS Revenue_Decile
    FROM customer C
    JOIN orders O ON C.CustomerID = O.CustomerID
    JOIN orderdetails OD ON O.OrderID = OD.OrderID
    GROUP BY 1, 2
)
SELECT
    CustomerID,
    Name,
    Total_Revenue
FROM CustomerRevenue
-- Filter where the customer is in the top 10% (Decile 1)
WHERE Revenue_Decile = 1
ORDER BY Total_Revenue DESC;


-- B. Customer Lifetime Value (CLV) Calculation per Customer. 

SELECT
    C.CustomerID,
    C.Name,
    COUNT(O.OrderID) AS Total_Orders,
    SUM(OD.LineTotal_INR) AS CLV_Total_Revenue
FROM customer C
LEFT JOIN orders O ON C.CustomerID = O.CustomerID
LEFT JOIN orderdetails OD ON O.OrderID = OD.OrderID
GROUP BY 1, 2
ORDER BY CLV_Total_Revenue DESC;

-- C. Average CLV by Age Group.

SELECT
    CASE
        WHEN C.Age BETWEEN 18 AND 25 THEN '18-25: Young Adult'
        WHEN C.Age BETWEEN 26 AND 40 THEN '26-40: Mid Career'
        WHEN C.Age BETWEEN 41 AND 55 THEN '41-55: Established'
        ELSE '56+: Senior'
    END AS Age_Group,
    COUNT(DISTINCT C.CustomerID) AS Total_Customers,
    SUM(OD.LineTotal_INR) / COUNT(DISTINCT C.CustomerID) AS Avg_CLV_INR
FROM customer C
LEFT JOIN Orders O ON C.CustomerID = O.CustomerID
LEFT JOIN orderdetails OD ON O.OrderID = OD.OrderID
GROUP BY 1
ORDER BY Avg_CLV_INR DESC;

-- Business Problem 3: Product Affinity and Upsell Potential
-- A. Products Purchased by Single-Order Customers. A proxy for Market Basket Analysis: identifies products that customers buy once and do not return for.

SELECT
    P.ProductName,
    P.Category,
    COUNT(OD.DetailID) AS Single_Order_Sales
FROM orderdetails OD
JOIN product P ON OD.ProductID = P.ProductID
WHERE OD.OrderID IN (
    SELECT OrderID FROM orders O
    WHERE O.CustomerID IN (
        SELECT CustomerID
        FROM orders
        GROUP BY CustomerID
        HAVING COUNT(OrderID) = 1
    )
)
GROUP BY 1, 2
ORDER BY Single_Order_Sales DESC
LIMIT 10;


-- B. Top 5 Potential Upsell Products. Identifies products that are frequently purchased together with a low-priced product.

WITH TopSellingProducts AS (
    --  Identify the Top 5 most frequently sold ProductIDs based on total quantity
    SELECT
        ProductID
    FROM orderdetails
    GROUP BY ProductID
    ORDER BY SUM(Quantity) DESC
    LIMIT 5 -- Change this number to analyze a different set of common base products
)
SELECT
    -- P2 is the product purchased alongside the Top 5 item
    P2.ProductName AS Upsell_Product,
    P2.Category,
    COUNT(DISTINCT OD2.OrderID) AS Co_Purchase_Count
FROM orderdetails OD1
                                            -- Filter line items (OD1) to only include the Top 5 selling products
JOIN TopSellingProducts TSP ON OD1.ProductID = TSP.ProductID
                                                                  -- Join to find other line items (OD2) in the SAME OrderID
JOIN orderdetails OD2 ON OD1.OrderID = OD2.OrderID
                                                              -- Join to get the details of the co-purchased product (P2)
JOIN Product P2 ON OD2.ProductID = P2.ProductID
                                                              -- Ensure the co-purchased product (P2) is DIFFERENT from the base product (TSP)
WHERE OD1.ProductID != OD2.ProductID
GROUP BY 1, 2
ORDER BY Co_Purchase_Count DESC
LIMIT 5;


-- C. Market Basket Analysis – Pairs of Products

SELECT 
    od1.ProductID AS ProductA,
    od2.ProductID AS ProductB,
    COUNT(*) AS FrequencyTogether
FROM orderdetails od1
JOIN orderdetails od2 
     ON od1.OrderID = od2.OrderID 
     AND od1.ProductID < od2.ProductID
GROUP BY od1.ProductID, od2.ProductID
ORDER BY FrequencyTogether DESC
LIMIT 20;

-- Demographic Purchasing Patterns (Age/Gender/City)

SELECT 
    c.Gender,
   c.City ,  AVG(od.LineTotal_INR) AS AvgSpend,
    COUNT(o.OrderID) AS TotalOrders
FROM Customer c
JOIN orders o ON c.CustomerID = o.CustomerID
JOIN orderdetails od ON o.OrderID = od.OrderID
GROUP BY c.Gender c.City
ORDER BY AvgSpend DESC;

-- Business Problem 5: Channel Performance
-- A.Total Revenue and Total Orders by Sales Channel. Identifies channels driving maximum profit.

SELECT
    O.Channel,
    COUNT(DISTINCT O.OrderID) AS Total_Orders,
    SUM(OD.LineTotal_INR) AS Total_Revenue_INR
FROM orders O
JOIN orderdetails OD ON O.OrderID = OD.OrderID
GROUP BY 1
ORDER BY Total_Revenue_INR DESC;

  -- B.Repeat Purchase Rate by Channel. Identifies channels driving maximum repeat purchases.

WITH ChannelMetrics AS (
    SELECT
        Channel,
        CustomerID,
        COUNT(OrderID) AS Orders_Count
    FROM orders
    GROUP BY Channel, CustomerID
)
SELECT
    Channel,
    CAST(SUM(CASE WHEN Orders_Count > 1 THEN 1 ELSE 0 END) AS REAL) * 100 / COUNT(CustomerID) AS Repeat_Purchase_Rate_PCT
FROM ChannelMetrics
GROUP BY Channel
ORDER BY Repeat_Purchase_Rate_PCT DESC;

-- 6. Customer RFM Segmentation (Recency, Frequency, Monetary)

WITH 
-- Recency: Days since last order
Recency AS (
    SELECT 
        c.CustomerID,
        DATEDIFF(CURDATE(), MAX(o.OrderDate)) AS Recency
    FROM customer c
    LEFT JOIN orders o ON c.CustomerID = o.CustomerID
    GROUP BY c.CustomerID
),

-- Frequency: Number of orders
Frequency AS (
    SELECT 
        c.CustomerID,
        COUNT(o.OrderID) AS Frequency
    FROM customer c
    LEFT JOIN orders o ON c.CustomerID = o.CustomerID
    GROUP BY c.CustomerID
),

-- Monetary: Total revenue
Monetary AS (
    SELECT 
        c.CustomerID,
        SUM(od.LineTotal_INR) AS Monetary
    FROM customer c
    LEFT JOIN orders o ON c.CustomerID = o.CustomerID
    LEFT JOIN orderdetails od ON o.OrderID = od.OrderID
    GROUP BY c.CustomerID
)

-- Final RFM Table
SELECT
    c.CustomerID,
    c.Name,
    r.Recency,
    f.Frequency,
    COALESCE(m.Monetary, 0) AS Monetary
FROM customer c
LEFT JOIN Recency r   ON c.CustomerID = r.CustomerID
LEFT JOIN Frequency f ON c.CustomerID = f.CustomerID
LEFT JOIN Monetary m  ON c.CustomerID = m.CustomerID
ORDER BY CustomerID;

-- 7.Seasonal and Other Key Metrics
-- A.Year-over-Year (YoY) Revenue Growth. Calculates the overall revenue growth metric.
WITH YearlyRevenue AS (
    SELECT
        YEAR(OrderDate) AS OrderYear,
        SUM(OD.LineTotal_INR) AS Annual_Revenue
    FROM orders O
    JOIN orderdetails OD ON O.OrderID = OD.OrderID
    GROUP BY YEAR(OrderDate)
)

SELECT
    Y.OrderYear,
    Y.Annual_Revenue,
    LAG(Y.Annual_Revenue, 1, 0) OVER (ORDER BY Y.OrderYear) AS Previous_Year_Revenue,
    CASE
        WHEN LAG(Y.Annual_Revenue, 1, 0) OVER (ORDER BY Y.OrderYear) = 0 THEN NULL
        ELSE ((Y.Annual_Revenue - LAG(Y.Annual_Revenue, 1, 0) OVER (ORDER BY Y.OrderYear)) * 100.0 /
              LAG(Y.Annual_Revenue, 1, 0) OVER (ORDER BY Y.OrderYear))
    END AS YoY_Growth_PCT
FROM YearlyRevenue Y
ORDER BY Y.OrderYear;

-- 9. "At-Risk" Churn Proxy: Customers Who Haven't Ordered in the Last 180 Days. Identifies customers who are likely churned/lapsed based on an inactivity window.

SELECT
    C.CustomerID,
    C.Name,
    MAX(O.OrderDate) AS Last_Order_Date,
    DATEDIFF(NOW(), MAX(O.OrderDate)) AS Days_Since_Last_Order
FROM customer C
LEFT JOIN orders O ON C.CustomerID = O.CustomerID
-- Group by customer ID and Name
GROUP BY C.CustomerID, C.Name
HAVING MAX(O.OrderDate) IS NULL OR DATEDIFF(NOW(), MAX(O.OrderDate)) > 180
ORDER BY Days_Since_Last_Order DESC;

