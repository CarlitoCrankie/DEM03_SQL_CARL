
-- SQL DML SCRIPT: Business KPIs and Advanced Queries
-- Inventory and Order Management System

-- BUSINESS KPI #1. Total Revenue
-- Calculating total Revenue from 'Shipped' or 'Delivered' orders

-- Start StopWatch
SET @start_time = NOW(3);

SELECT
    SUM(TotalAmount) AS TotalRevenue,
    COUNT(OrderID) AS CompleteOrders
FROM Orders
WHERE OrderStatus IN ('Shipped', 'Delivered');

-- BUSINESS KPI #1.1 Incomplete or Pending Orders
SELECT 
    SUM(TotalAmount) AS TotalAmountUnspent,
    COUNT(OrderID) AS NumberOfOrders
FROM Orders 
WHERE OrderStatus IN ('Pending')

-- -- End StopWatch
-- SET @end_time = NOW(3);
-- SET @execution_time = TIMESTAMPDIFF(MICROSECOND, @start_time, @end_time) / 1000;

-- -- Log query performance
-- CALL LogQueryPerformance('TotalRevenue_KPI', @execution_time, 1, 'SELECT', TRUE, NULL);


-- BUSINESS KPI #2. Top 10 Customers by Total Spending
SELECT 
    c.CustomerID,
    c.FullName,
    SUM(o.TotalAmount) AS TotalAmountSpent,
    COUNT(o.OrderID) AS NumberOfOrders
FROM Customers c
INNER JOIN Orders o ON c.CustomerID = o.CustomerID
GROUP BY c.CustomerID, c.FullName
ORDER BY TotalAmountSpent DESC
LIMIT 10;

-- BUSINESS KPI #3. Best Selling Products ( Top 5 by Quantity)
SELECT 
    p.ProductID,
    p.ProductName,
    p.Category,
    SUM(oi.Quantity) AS TotalQuantitySold,
    SUM(oi.Quantity * o.PriceAtPurchase) AS TotalRevenue
FROM Products p
INNER JOIN OrderItems oi on p.ProductID = oi.ProductID
INNER JOIN Orders o ON oi.OrderID = o.OrderID
WHERE o.OrderStatus IN ('Shipped', 'Delivered')
GROUP BY p.ProductID, p.ProductName, p.Category
ORDER BY TotalQuantitySold DESC
LIMIT 5;


-- BUSINESS KPI #4. Monthly Sales Trend
-- Showing Total Sales revenue for each Month

SELECT
    DATE_FORMAT(OrderDate, '%Y-%m') AS SalesMonth,
    COUNT(OrderID) AS TotalOrders,
    SUM(TotalAmount) AS TotalRevenue,
    AVG(TotalAmount) AS AverageOrderValue
FROM Orders
WHERE OrderStatus IN ('Shipped', 'Delivered')
GROUP BY DATE_FORMAT(OrderDate, '%Y-%m')
ORDER BY SalesMonth;


-- ANALYTICAL QUERY #1: Sales Rank by Category (WINDOW FUNCTION)
WITH ProductSales AS (
    SELECT
        p.ProductID,
        p.Category,
        p.ProductName,
        SUM(oi.Quantity * oi.PriceAtPurchase) AS TotalSalesRevenue
    FROM Products p
    INNER JOIN OrderItems oi ON p.ProductID = oi.ProductID
    INNER JOIN Orders o ON oi.OrderID = o.OrderID
    WHERE OrderStatus IN ('Shipped', 'Delivered')
    GROUP BY p.ProductID, p.Category, p.ProductName
)
SELECT
    Category,
    ProductName,
    TotalSalesRevenue,
    RANK() OVER (
        PARTITION BY Category
        ORDER BY TotalSalesRevenue DESC
    ) AS CategoryRank,
    DENSE_RANK() OVER (
        PARTITION BY Category
        ORDER BY TotalSalesRevenue DESC
    ) As CategoryDenseRank,
    ROW_NUMBER() OVER (
        PARTITION BY Category
        ORDER BY TotalSalesRevenue DESC
    ) AS RowNumber
FROM ProductSales
ORDER BY Category, CategoryRank;


-- ANALYTICAL QUERY #2: Customer Order Frequency

SELECT
    c.CustomerID,
    c.FullName,
    o.OrderID,
    o.OrderDate AS CurrentOrderDate,
    LAG(o.OrderDate, 1) OVER (
        PARTITION BY c.CustomerID
        ORDER BY o.OrderDate
    ) AS PreviousOrderDate,
    LEAD(o.OrderDate, 1) OVER (
        PARTITION BY c.CustomerID
        ORDER BY o.OrderDate
    ) AS NextOrderDate,
    DATEDIFF(
        o.OrderDate,
        LAG(o.OrderDate, 1) OVER (PARTITION BY c.CustomerID ORDER BY o.OrderDate)
    ) AS DaySincePreviousOrder,
    ROW_NUMBER() OVER (
        PARTITION BY c.CustomerID
        ORDER BY o.OrderDate
    ) AS OrderSequence,
    COUNT(*) OVER (
        PARTITION BY c.CustomerID
    ) AS TotalCustomersOrders
FROM Customers c
INNER JOIN Orders o on c.CustomerID = o.CustomerID
ORDER BY c.CustomerID, o.OrderDate;


-- ADDITIONAL ANALYTICAL QUERIES

-- Product Performance with Inventory Status
SELECT 
    p.ProductID,
    p.ProductName,
    p.Category,
    p.Price AS CurrentPrice,
    i.QuantityOnHand,
    COALESCE(SUM(oi.Quantity), 0) AS TotalSold,
    COALESCE(SUM(oi.Quantity * oi.PriceAtPurchase), 0) AS TotalRevenue,
    CASE 
        WHEN i.QuantityOnHand = 0 THEN 'Out of Stock'
        WHEN i.QuantityOnHand < 50 THEN 'Low Stock'
        ELSE 'In Stock'
    END AS StockStatus
FROM Products p
LEFT JOIN Inventory i ON p.ProductID = i.ProductID
LEFT JOIN OrderItems oi ON p.ProductID = oi.ProductID
LEFT JOIN Orders o ON oi.OrderID = o.OrderID 
    AND o.OrderStatus IN ('Shipped', 'Delivered')
GROUP BY p.ProductID, p.ProductName, p.Category, p.Price, i.QuantityOnHand
ORDER BY TotalRevenue DESC;


-- Customer Lifetime Value Analysis
SELECT 
    c.CustomerID,
    c.FullName,
    c.Email,
    COUNT(o.OrderID) AS TotalOrders,
    SUM(o.TotalAmount) AS LifetimeValue,
    AVG(o.TotalAmount) AS AverageOrderValue,
    MIN(o.OrderDate) AS FirstOrderDate,
    MAX(o.OrderDate) AS LastOrderDate,
    DATEDIFF(MAX(o.OrderDate), MIN(o.OrderDate)) AS CustomerTenureDays
FROM Customers c
LEFT JOIN Orders o ON c.CustomerID = o.CustomerID
GROUP BY c.CustomerID, c.FullName, c.Email
HAVING TotalOrders > 0
ORDER BY LifetimeValue DESC;


-- PERFORMANCE OPTIMIZATION: VIEWS
-- View 1: Customer Sales Summary
CREATE OR REPLACE VIEW CustomerSalesSummary AS 
SELECT
    c.CustomerID,
    c.FullName,
    c.Email,
    COUNT(o.OrderID) AS TotalOrders,
    SUM(o.TotalAmount) AS TotalAmountSpent,
    AVG(o.TotalAmount) AS AverageOrderValue,
    MAX(o.OrderDate) AS LastOrderDate,
    SUM(CASE WHEN o.OrderStatus = 'Pending' THEN 1 ELSE 0 END) AS PendingOrders,
    SUM(CASE WHEN o.OrderStatus = 'Shipped' THEN 1 ELSE 0 END) AS ShippedOrders,
    SUM(CASE WHEN o.OrderStatus = 'Delivered' THEN 1 ELSE 0 END) AS DeliveredOrders
FROM Customers c
LEFT JOIN Orders o ON c.CustomerID = o.CustomerID
GROUP BY c.CustomerID, c.FullName, c.Email;


-- View 2: Product Inventory Status
CREATE OR REPLACE VIEW ProductInventoryStatus AS 
SELECT
    p.ProductID,
    p.ProductName,
    p.Category,
    p.Price,
    i.QuantityOnHand,
    COALESCE(Sum(oi.Quantity), 0) AS TotalSold,
    CASE
        WHEN i.QuantityOnHand = 0 THEN 'Out of Stock'
        WHEN i.QuantityOnHand < 50 THEN 'Low Stock'
        WHEN i.QuantityOnHand < 100 THEN 'Medium Stock'
    ELSE 'High Stock'
    END AS StockStatus
FROM Products p
LEFT JOIN Inventory i ON p.ProductID = i.ProductID
LEFT JOIN OrderItems oi ON p.ProductID = oi.ProductID
LEFT JOIN Orders o ON oi.OrderID = o.OrderID
    AND o.OrderStatus IN ('Shipped', 'Delivered')
GROUP BY p.ProductID, p.ProductName, p.Category, p.Price, i.QuantityOnHand ;

-- STORED PROCEDURE: Process New Order

DELIMITER //

CREATE PROCEDURE ProcessNewOrder(
    IN p_CustomerID INT,
    IN p_ProductID INT,
    IN p_Quantity INT,
    OUT p_OrderID INT,
    OUT p_Message VARCHAR(255)
)
proc: BEGIN
    -- Declare variables
    DECLARE v_QuantityOnHand INT;
    DECLARE v_ProductPrice DECIMAL(10, 2);
    DECLARE v_TotalAmount DECIMAL(10, 2);
    DECLARE v_OrderExists INT DEFAULT 0;
    DECLARE v_Exists      INT DEFAULT 0;

    -- Error handler for any SQL errors
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_Message = 'Error: Transaction failed and was rolled back.';
        SET p_OrderID = NULL;
    END;

    -- Quantity must be positive (Guard Check)
    IF p_Quantity is NULL OR p_Quantity <= 0 THEN
        SET p_Message = 'Error: Quantity must be a positive integer.';
        SET p_OrderID = NULL;
        LEAVE proc;
    END IF;

    -- Start transaction
    START TRANSACTION;

    -- Check if customer exists
    SELECT COUNT(*) INTO v_OrderExists
    FROM Customers
    WHERE CustomerID = p_CustomerID;

    IF v_OrderExists = 0 THEN
        SET p_Message = 'Error: Customer ID does not exist.';
        SET p_OrderID = NULL;
        ROLLBACK;
        LEAVE proc;
    END IF;

    -- Validate product and get price
    SELECT COUNT(*) INTO v_Exists
    FROM Products
    WHERE ProductID = p_ProductID;

    IF v_Exists = 0 THEN
        SET p_Message = 'Error: Product ID does not exist.';
        SET p_OrderID = NULL;
        ROLLBACK;
        LEAVE proc;
    END IF;

    -- Get Product Price
    SELECT Price INTO v_ProductPrice
    FROM Products
    WHERE ProductID = p_ProductID;

    IF v_ProductPrice is NULL THEN
        SET p_Message = 'Error: Product price not set.';
        SET p_OrderID = NULL;
        ROLLBACK;
        LEAVE proc;
    END IF;

    -- Check Inventory
    SELECT QuantityOnHand INTO v_QuantityOnHand
    FROM Inventory
    WHERE ProductID = p_ProductID
    FOR UPDATE;

    IF v_QuantityOnHand IS NULL THEN
        SET p_Message = 'Error: Product not found in inventory.';
        SET p_OrderID = NULL;
        ROLLBACK;
        LEAVE proc;
    ELSEIF v_QuantityOnHand < p_Quantity THEN
        SET p_Message = CONCAT('Error: Insufficient stock. Available: ', v_QuantityOnHand);
        SET p_OrderID = NULL;
        ROLLBACK;
        LEAVE proc;
    END IF;
                
    -- Calculate total amount
    SET v_TotalAmount = v_ProductPrice * p_Quantity;
                
    -- Create new order
    INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, OrderStatus)
    VALUES (p_CustomerID, CURDATE(), v_TotalAmount, 'Pending');
                
    SET p_OrderID = LAST_INSERT_ID();
                
    -- Create order item
    INSERT INTO OrderItems (OrderID, ProductID, Quantity, PriceAtPurchase)                
    VALUES (p_OrderID, p_ProductID, p_Quantity, v_ProductPrice);
                
    -- Update inventory
    UPDATE Inventory
    SET QuantityOnHand = QuantityOnHand - p_Quantity
    WHERE ProductID = p_ProductID;
                
    -- Commit transaction
    COMMIT;
                
    SET p_Message = CONCAT('Success: Order ', p_OrderID, ' created successfully.');

END //


-- Update Order Status

DELIMITER //

CREATE PROCEDURE UpdateOrderStatus(
    IN p_OrderID INT,
    IN p_NewStatus VARCHAR(20),
    OUT p_Message VARCHAR(255)
)
proc: BEGIN
    DECLARE v_OrderExists INT DEFAULT 0;
    
    -- Validate Allowed statuses
    IF p_NewStatus IS NULL OR p_NewStatus NOT IN ('Pending', 'Shipped', 'Delivered') THEN
        SET p_Message = CONCAT('Error: Invalid status value: ', COALESCE(p_NewStatus, 'NULL'), '.');
        LEAVE proc;
    END IF;


    SELECT COUNT(*) INTO v_OrderExists
    FROM Orders
    WHERE OrderID = p_OrderID;
    
    IF v_OrderExists = 0 THEN
        SET p_Message = 'Error: Order ID does not exist.';
        LEAVE proc;
    END IF;

    START TRANSACTION;


    UPDATE Orders
    SET OrderStatus = p_NewStatus
    WHERE OrderID = p_OrderID;

    COMMIT;

    SET p_Message = CONCAT('Success: Order ', p_OrderID, ' status updated to ', p_NewStatus);
END//


-- SUMMARY REPORT: Database Statistics
SELECT 'DATABASE SUMMARY STATISTICS' AS ReportSection;

SELECT 
    'Total Customers' AS Metric,
    COUNT(*) AS Value
FROM Customers
UNION ALL
SELECT 
    'Total Products' AS Metric,
    COUNT(*) AS Value
FROM Products
UNION ALL
SELECT 
    'Total Orders' AS Metric,
    COUNT(*) AS Value
FROM Orders
UNION ALL
SELECT 
    'Total Revenue (Shipped/Delivered)' AS Metric,
    SUM(TotalAmount) AS Value
FROM Orders
WHERE OrderStatus IN ('Shipped', 'Delivered')
UNION ALL
SELECT 
    'Average Order Value' AS Metric,
    AVG(TotalAmount) AS Value
FROM Orders
WHERE OrderStatus IN ('Shipped', 'Delivered');
