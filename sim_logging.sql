-- Drop existing logging tables if they exist
DROP TABLE IF EXISTS OrderAuditLog;
DROP TABLE IF EXISTS InventoryChangeLog;
DROP TABLE IF EXISTS QueryPerformanceLog;
DROP TABLE IF EXISTS UserActivityLog;
DROP TABLE IF EXISTS SystemLog;

-- Main system log 
CREATE TABLE SystemLog (
    LogID INT PRIMARY KEY AUTO_INCREMENT,
    LogTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LogLevel ENUM('INFO', 'WARNING', 'ERROR') NOT NULL DEFAULT 'INFO',
    Category VARCHAR(50) NOT NULL,
    Message TEXT NOT NULL,
    TableName VARCHAR(50),
    RecordID INT,
    INDEX idx_time (LogTime),
    INDEX idx_level (LogLevel)
) ENGINE=InnoDB;

-- Order audit log
CREATE TABLE OrderAuditLog (
    AuditID INT PRIMARY KEY AUTO_INCREMENT,
    LogTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    OrderID INT,
    CustomerID INT,
    ProductID INT,
    Action VARCHAR(20) NOT NULL,
    Quantity INT,
    Success BOOLEAN NOT NULL,
    ErrorMsg TEXT,
    INDEX idx_order (OrderID),
    INDEX idx_time (LogTime)
) ENGINE=InnoDB;

-- Inventory change log
CREATE TABLE InventoryChangeLog (
    ChangeID INT PRIMARY KEY AUTO_INCREMENT,
    LogTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ProductID INT NOT NULL,
    ChangeType VARCHAR(20) NOT NULL,
    OldQty INT NOT NULL,
    NewQty INT NOT NULL,
    OrderID INT,
    Reason VARCHAR(255),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    INDEX idx_product (ProductID),
    INDEX idx_time (LogTime)
) ENGINE=InnoDB;

--  LOGGING PROCEDURES
DELIMITER //

--  system log procedure
CREATE PROCEDURE LogEvent(
    IN p_Level VARCHAR(20),
    IN p_Category VARCHAR(50),
    IN p_Message TEXT
)
BEGIN
    INSERT INTO SystemLog (LogLevel, Category, Message)
    VALUES (p_Level, p_Category, p_Message);
END//

--  inventory change log
CREATE PROCEDURE LogInventory(
    IN p_ProductID INT,
    IN p_Type VARCHAR(20),
    IN p_OldQty INT,
    IN p_NewQty INT,
    IN p_OrderID INT,
    IN p_Reason VARCHAR(255)
)
BEGIN
    INSERT INTO InventoryChangeLog (ProductID, ChangeType, OldQty, NewQty, OrderID, Reason)
    VALUES (p_ProductID, p_Type, p_OldQty, p_NewQty, p_OrderID, p_Reason);
END//

-- ORDER PROCESSING 

DROP PROCEDURE IF EXISTS ProcessOrderWithLog//

CREATE PROCEDURE ProcessOrderWithLog(
    IN p_CustomerID INT,
    IN p_ProductID INT,
    IN p_Quantity INT,
    OUT p_OrderID INT,
    OUT p_Message VARCHAR(255)
)
BEGIN
    DECLARE v_Stock INT;
    DECLARE v_Price DECIMAL(10, 2);
    DECLARE v_Total DECIMAL(10, 2);
    DECLARE v_ProductName VARCHAR(150);
    DECLARE v_ErrorCode VARCHAR(10);
    DECLARE v_ErrorMsg TEXT;
    DECLARE v_RetryCount INT DEFAULT 0;
    DECLARE v_MaxRetries INT DEFAULT 3;
    DECLARE v_Success BOOLEAN DEFAULT FALSE;
    DECLARE v_StockBeforeUpdate INT;
    
    -- Error handler
    DECLARE CONTINUE HANDLER FOR 1205, 1213 
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_ErrorCode = RETURNED_SQLSTATE,
            v_ErrorMsg = MESSAGE_TEXT;
        
        SET v_RetryCount = v_RetryCount + 1;
        
        -- Log retry attempt
        INSERT INTO SystemLog (LogLevel, Category, Message)
        VALUES ('WARNING', 'ORDER', CONCAT('Retry ', v_RetryCount, ' after lock issue: ', v_ErrorMsg));
        
        ROLLBACK;
    END;
    
    -- Error handler for all other errors (non-retryable)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_ErrorCode = RETURNED_SQLSTATE,
            v_ErrorMsg = MESSAGE_TEXT;
        
        -- Rollback 
        ROLLBACK;
        
        -- Log the error
        INSERT INTO SystemLog (LogLevel, Category, Message)
        VALUES ('ERROR', 'ORDER', CONCAT('Order failed after ', v_RetryCount, ' attempts: ', v_ErrorMsg));
        
        -- Log failed audit
        INSERT INTO OrderAuditLog (OrderID, CustomerID, ProductID, Action, Success, ErrorMsg)
        VALUES (NULL, p_CustomerID, p_ProductID, 'CREATE', FALSE, CONCAT('Error after ', v_RetryCount, ' retries: ', v_ErrorMsg));
        
        SET p_Message = CONCAT('Error: Transaction failed - ', v_ErrorMsg);
        SET p_OrderID = NULL;
    END;
    
    -- Log start
    CALL LogEvent('INFO', 'ORDER', CONCAT('Processing order: Customer ', p_CustomerID, ', Product ', p_ProductID, ', Qty ', p_Quantity));
    
    -- RETRY LOOP
    retry_loop: WHILE v_RetryCount < v_MaxRetries AND v_Success = FALSE DO
        
        -- Reset error flag
        SET v_ErrorCode = NULL;
        
        BEGIN
            START TRANSACTION;
            
            -- Validate quantity
            IF p_Quantity IS NULL OR p_Quantity <= 0 THEN
                CALL LogEvent('WARNING', 'ORDER', 'Invalid quantity');
                INSERT INTO OrderAuditLog (OrderID, CustomerID, ProductID, Action, Success, ErrorMsg)
                VALUES (NULL, p_CustomerID, p_ProductID, 'CREATE', FALSE, 'Invalid quantity');
                SET p_Message = 'Error: Invalid quantity';
                SET p_OrderID = NULL;
                ROLLBACK;
                LEAVE retry_loop;
            END IF;
            
            -- Check customer exists
            IF NOT EXISTS (SELECT 1 FROM Customers WHERE CustomerID = p_CustomerID) THEN
                CALL LogEvent('WARNING', 'ORDER', CONCAT('Customer ', p_CustomerID, ' not found'));
                INSERT INTO OrderAuditLog (OrderID, CustomerID, ProductID, Action, Success, ErrorMsg)
                VALUES (NULL, p_CustomerID, p_ProductID, 'CREATE', FALSE, 'Customer not found');
                SET p_Message = 'Error: Customer not found';
                SET p_OrderID = NULL;
                ROLLBACK;
                LEAVE retry_loop;
            END IF;
            
            -- Get product details with row lock
            SELECT Price, ProductName INTO v_Price, v_ProductName
            FROM Products
            WHERE ProductID = p_ProductID
            FOR UPDATE; 
            
            IF v_Price IS NULL THEN
                CALL LogEvent('WARNING', 'ORDER', CONCAT('Product ', p_ProductID, ' not found'));
                INSERT INTO OrderAuditLog (OrderID, CustomerID, ProductID, Action, Success, ErrorMsg)
                VALUES (NULL, p_CustomerID, p_ProductID, 'CREATE', FALSE, 'Product not found');
                SET p_Message = 'Error: Product not found';
                SET p_OrderID = NULL;
                ROLLBACK;
                LEAVE retry_loop;
            END IF;
            
            -- Check inventory
            SELECT QuantityOnHand INTO v_Stock
            FROM Inventory
            WHERE ProductID = p_ProductID
            FOR UPDATE; 
            
            SET v_StockBeforeUpdate = v_Stock;
            
            IF v_Stock IS NULL THEN
                CALL LogEvent('WARNING', 'ORDER', CONCAT('No inventory for product ', p_ProductID));
                INSERT INTO OrderAuditLog (OrderID, CustomerID, ProductID, Action, Success, ErrorMsg)
                VALUES (NULL, p_CustomerID, p_ProductID, 'CREATE', FALSE, 'No inventory record');
                SET p_Message = 'Error: No inventory record';
                SET p_OrderID = NULL;
                ROLLBACK;
                LEAVE retry_loop;
            END IF;
            
            IF v_Stock < p_Quantity THEN
                CALL LogEvent('WARNING', 'ORDER', CONCAT('Insufficient stock: need ', p_Quantity, ', have ', v_Stock));
                INSERT INTO OrderAuditLog (OrderID, CustomerID, ProductID, Action, Success, ErrorMsg)
                VALUES (NULL, p_CustomerID, p_ProductID, 'CREATE', FALSE, CONCAT('Insufficient stock: ', v_Stock, ' available'));
                SET p_Message = CONCAT('Error: Only ', v_Stock, ' units available');
                SET p_OrderID = NULL;
                ROLLBACK;
                LEAVE retry_loop;
            END IF;
            
            -- Create order
            SET v_Total = v_Price * p_Quantity;
            
            INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, OrderStatus)
            VALUES (p_CustomerID, CURDATE(), v_Total, 'Pending');
            
            SET p_OrderID = LAST_INSERT_ID();
            
            -- Create order item
            INSERT INTO OrderItems (OrderID, ProductID, Quantity, PriceAtPurchase)
            VALUES (p_OrderID, p_ProductID, p_Quantity, v_Price);
            
            -- Update inventory
            UPDATE Inventory
            SET QuantityOnHand = QuantityOnHand - p_Quantity
            WHERE ProductID = p_ProductID;
            
            -- Verify the update worked correctly
            SELECT QuantityOnHand INTO v_Stock FROM Inventory WHERE ProductID = p_ProductID;
            
            IF v_Stock != (v_StockBeforeUpdate - p_Quantity) THEN
                -- Inventory mismatch, rollback
                CALL LogEvent('ERROR', 'ORDER', 'Inventory update verification failed');
                INSERT INTO OrderAuditLog (OrderID, CustomerID, ProductID, Action, Success, ErrorMsg)
                VALUES (p_OrderID, p_CustomerID, p_ProductID, 'CREATE', FALSE, 'Inventory verification failed');
                SET p_Message = 'Error: Inventory update failed verification';
                SET p_OrderID = NULL;
                ROLLBACK;
                LEAVE retry_loop;
            END IF;
            
            -- Log inventory change
            CALL LogInventory(p_ProductID, 'SALE', v_StockBeforeUpdate, v_Stock, p_OrderID, 
                              CONCAT('Order #', p_OrderID, ' - ', v_ProductName));
            
            -- Log success in audit
            INSERT INTO OrderAuditLog (OrderID, CustomerID, ProductID, Action, Quantity, Success)
            VALUES (p_OrderID, p_CustomerID, p_ProductID, 'CREATE', p_Quantity, TRUE);
            
            -- Commit transaction
            COMMIT;
            
            -- Mark as successful
            SET v_Success = TRUE;
            
            -- Log success
            CALL LogEvent('INFO', 'ORDER', CONCAT('Order ', p_OrderID, ' created successfully'); 

DELIMITER ;

-- ORDER CANCELLATION
DELIMITER //

CREATE PROCEDURE CancelOrder(
    IN p_OrderID INT,
    IN p_Reason VARCHAR(255),
    OUT p_Message VARCHAR(255)
)
BEGIN
    DECLARE v_OrderStatus VARCHAR(20);
    DECLARE v_CustomerID INT;
    DECLARE v_ErrorCode VARCHAR(10);
    DECLARE v_ErrorMsg TEXT;
    DECLARE v_ItemCount INT DEFAULT 0;
    
    -- Error handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_ErrorCode = RETURNED_SQLSTATE,
            v_ErrorMsg = MESSAGE_TEXT;
        
        ROLLBACK;
        
        INSERT INTO SystemLog (LogLevel, Category, Message)
        VALUES ('ERROR', 'ORDER', CONCAT('Order cancellation failed for Order ', p_OrderID, ': ', v_ErrorMsg));
        
        SET p_Message = CONCAT('Error: Cancellation failed - ', v_ErrorMsg);
    END;
    
    -- Log cancellation attempt
    CALL LogEvent('INFO', 'ORDER', CONCAT('Attempting to cancel Order ', p_OrderID, ': ', p_Reason));
    
    START TRANSACTION;
    
    -- Check if order exists and get status
    SELECT OrderStatus, CustomerID INTO v_OrderStatus, v_CustomerID
    FROM Orders
    WHERE OrderID = p_OrderID
    FOR UPDATE;
    
    IF v_OrderStatus IS NULL THEN
        CALL LogEvent('WARNING', 'ORDER', CONCAT('Order ', p_OrderID, ' not found'));
        SET p_Message = 'Error: Order not found';
        ROLLBACK;
        LEAVE;
    END IF;
    
    -- Check if order can be cancelled
    IF v_OrderStatus = 'Delivered' THEN
        CALL LogEvent('WARNING', 'ORDER', CONCAT('Cannot cancel delivered Order ', p_OrderID));
        SET p_Message = 'Error: Cannot cancel delivered order';
        ROLLBACK;
        LEAVE;
    END IF;
    
    IF v_OrderStatus = 'Cancelled' THEN
        CALL LogEvent('WARNING', 'ORDER', CONCAT('Order ', p_OrderID, ' already cancelled'));
        SET p_Message = 'Warning: Order already cancelled';
        ROLLBACK;
        LEAVE;
    END IF;
    
    -- Restore inventory for all items in the order
    BEGIN
        DECLARE done INT DEFAULT FALSE;
        DECLARE v_ProductID INT;
        DECLARE v_Quantity INT;
        DECLARE v_StockBefore INT;
        DECLARE v_StockAfter INT;
        
        DECLARE item_cursor CURSOR FOR 
            SELECT ProductID, Quantity 
            FROM OrderItems 
            WHERE OrderID = p_OrderID;
        
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
        
        OPEN item_cursor;
        
        restore_loop: LOOP
            FETCH item_cursor INTO v_ProductID, v_Quantity;
            
            IF done THEN
                LEAVE restore_loop;
            END IF;
            
            -- Get current stock
            SELECT QuantityOnHand INTO v_StockBefore
            FROM Inventory
            WHERE ProductID = v_ProductID
            FOR UPDATE;
            
            -- Restore inventory
            UPDATE Inventory
            SET QuantityOnHand = QuantityOnHand + v_Quantity
            WHERE ProductID = v_ProductID;
            
            SET v_StockAfter = v_StockBefore + v_Quantity;
            
            -- Log inventory restoration
            CALL LogInventory(v_ProductID, 'RETURN', v_StockBefore, v_StockAfter, p_OrderID,
                              CONCAT('Order #', p_OrderID, ' cancelled - ', p_Reason));
            
            SET v_ItemCount = v_ItemCount + 1;
        END LOOP;
        
        CLOSE item_cursor;
    END;
    
    -- Update order status
    UPDATE Orders
    SET OrderStatus = 'Cancelled'
    WHERE OrderID = p_OrderID;
    
    -- Log in audit
    INSERT INTO OrderAuditLog (OrderID, CustomerID, ProductID, Action, Success, ErrorMsg)
    VALUES (p_OrderID, v_CustomerID, NULL, 'CANCEL', TRUE, p_Reason);
    
    COMMIT;
    
    -- Log success
    CALL LogEvent('INFO', 'ORDER', CONCAT('Order ', p_OrderID, ' cancelled successfully. ', v_ItemCount, ' items restored to inventory'));
    
    SET p_Message = CONCAT('Success: Order ', p_OrderID, ' cancelled and inventory restored');
    
END//

DELIMITER ;


-- TRIGGERS FOR AUTO-LOGGING
DELIMITER //

-- Log order status changes
DROP TRIGGER IF EXISTS log_order_status//
CREATE TRIGGER log_order_status
AFTER UPDATE ON Orders
FOR EACH ROW
BEGIN
    IF OLD.OrderStatus != NEW.OrderStatus THEN
        INSERT INTO SystemLog (LogLevel, Category, Message, TableName, RecordID)
        VALUES ('INFO', 'ORDER', 
                CONCAT('Status changed: ', OLD.OrderStatus, ' -> ', NEW.OrderStatus),
                'Orders', NEW.OrderID);
    END IF;
END//

-- Log inventory updates
DROP TRIGGER IF EXISTS log_inventory_change//
CREATE TRIGGER log_inventory_change
AFTER UPDATE ON Inventory
FOR EACH ROW
BEGIN
    IF OLD.QuantityOnHand != NEW.QuantityOnHand THEN
        INSERT INTO InventoryChangeLog (ProductID, ChangeType, OldQty, NewQty, Reason)
        VALUES (NEW.ProductID, 'ADJUSTMENT', OLD.QuantityOnHand, NEW.QuantityOnHand, 'Direct update');
        
        INSERT INTO SystemLog (LogLevel, Category, Message, TableName, RecordID)
        VALUES ('INFO', 'INVENTORY', 
                CONCAT('Stock changed: ', OLD.QuantityOnHand, ' -> ', NEW.QuantityOnHand),
                'Inventory', NEW.ProductID);
    END IF;
END//

-- Log price changes
DROP TRIGGER IF EXISTS log_price_change//
CREATE TRIGGER log_price_change
AFTER UPDATE ON Products
FOR EACH ROW
BEGIN
    IF OLD.Price != NEW.Price THEN
        INSERT INTO SystemLog (LogLevel, Category, Message, TableName, RecordID)
        VALUES ('INFO', 'PRODUCT', 
                CONCAT('Price changed: $', OLD.Price, ' -> $', NEW.Price),
                'Products', NEW.ProductID);
    END IF;
END//

DELIMITER ;


--  VIEWS

-- View all recent logs
CREATE OR REPLACE VIEW RecentLogs AS
SELECT 
    LogID,
    LogTime,
    LogLevel,
    Category,
    Message
FROM SystemLog
ORDER BY LogTime DESC
LIMIT 100;

-- View errors only
CREATE OR REPLACE VIEW ErrorLog AS
SELECT 
    LogID,
    LogTime,
    Category,
    Message,
    TableName,
    RecordID
FROM SystemLog
WHERE LogLevel = 'ERROR'
ORDER BY LogTime DESC;

-- View order activity
CREATE OR REPLACE VIEW OrderActivity AS
SELECT 
    a.LogTime,
    a.OrderID,
    a.CustomerID,
    a.ProductID,
    a.Action,
    a.Quantity,
    CASE WHEN a.Success THEN 'Success' ELSE 'Failed' END AS Status,
    a.ErrorMsg
FROM OrderAuditLog a
ORDER BY a.LogTime DESC;

-- View inventory activity
CREATE OR REPLACE VIEW InventoryActivity AS
SELECT 
    i.LogTime,
    p.ProductName,
    i.ChangeType,
    i.OldQty,
    i.NewQty,
    (i.NewQty - i.OldQty) AS Change,
    i.OrderID,
    i.Reason
FROM InventoryChangeLog i
JOIN Products p ON i.ProductID = p.ProductID
ORDER BY i.LogTime DESC;

-- Daily summary
CREATE OR REPLACE VIEW DailySummary AS
SELECT 
    DATE(LogTime) AS Date,
    COUNT(*) AS TotalLogs,
    SUM(CASE WHEN LogLevel = 'ERROR' THEN 1 ELSE 0 END) AS Errors,
    SUM(CASE WHEN LogLevel = 'WARNING' THEN 1 ELSE 0 END) AS Warnings,
    SUM(CASE WHEN LogLevel = 'INFO' THEN 1 ELSE 0 END) AS Info
FROM SystemLog
GROUP BY DATE(LogTime)
ORDER BY Date DESC;


--  MAINTENANCE
DELIMITER //

-- Clean old logs (keep last 30 days)
CREATE PROCEDURE CleanOldLogs()
BEGIN
    DECLARE rows_deleted INT;
    
    DELETE FROM SystemLog WHERE LogTime < DATE_SUB(NOW(), INTERVAL 30 DAY);
    SET rows_deleted = ROW_COUNT();
    
    INSERT INTO SystemLog (LogLevel, Category, Message)
    VALUES ('INFO', 'MAINTENANCE', CONCAT('Cleaned ', rows_deleted, ' old log entries'));
    
    DELETE FROM OrderAuditLog WHERE LogTime < DATE_SUB(NOW(), INTERVAL 30 DAY);
    DELETE FROM InventoryChangeLog WHERE LogTime < DATE_SUB(NOW(), INTERVAL 30 DAY);
END//

DELIMITER ;


-- INITIALIZATION AND TESTING

-- Log system startup
INSERT INTO SystemLog (LogLevel, Category, Message)
VALUES ('INFO', 'SYSTEM', 'Simple logging system initialized');

-- Show summary
SELECT 'Simple Logging System Ready' AS Status;

SELECT 
    'Logging Tables' AS Info,
    COUNT(*) AS TablesCreated 
FROM information_schema.tables 
WHERE table_schema = 'inventory_system' 
AND table_name IN ('SystemLog', 'OrderAuditLog', 'InventoryChangeLog');

-- =====================================================
-- QUICK TEST EXAMPLES
-- =====================================================

/*
TEST THE LOGGING SYSTEM WITH RETRY AND ROLLBACK:

1. Manual logging:
   CALL LogEvent('INFO', 'TEST', 'Testing the logging system');
   SELECT * FROM RecentLogs LIMIT 5;
   
2. Process a successful order:
   CALL ProcessOrderWithLog(1, 2, 3, @order, @msg);
   SELECT @order AS OrderID, @msg AS Message;
   SELECT * FROM OrderActivity LIMIT 5;
   SELECT * FROM InventoryActivity LIMIT 5;
   
3. View recent logs:
   SELECT * FROM RecentLogs LIMIT 20;
   
4. View errors only:
   SELECT * FROM ErrorLog;
   
5. Test insufficient stock (should fail gracefully):
   CALL ProcessOrderWithLog(1, 1, 1000, @order, @msg);
   SELECT @order, @msg;
   SELECT * FROM ErrorLog LIMIT 1;
   
6. Test invalid customer (should fail with rollback):
   CALL ProcessOrderWithLog(999, 2, 5, @order, @msg);
   SELECT @order, @msg;
   SELECT * FROM OrderActivity WHERE Success = FALSE LIMIT 3;
   
7. Cancel an order (with inventory restoration):
   -- First create an order
   CALL ProcessOrderWithLog(2, 3, 2, @order, @msg);
   SELECT 'Created order:', @order;
   
   -- Check inventory before cancellation
   SELECT ProductID, QuantityOnHand FROM Inventory WHERE ProductID = 3;
   
   -- Cancel the order
   CALL CancelOrder(@order, 'Customer requested cancellation', @cancel_msg);
   SELECT @cancel_msg;
   
   -- Verify inventory restored
   SELECT ProductID, QuantityOnHand FROM Inventory WHERE ProductID = 3;
   SELECT * FROM InventoryActivity WHERE OrderID = @order;
   
8. Test multiple orders concurrently (simulates retry scenario):
   -- Open multiple MySQL Workbench tabs and run simultaneously
   -- Tab 1:
   CALL ProcessOrderWithLog(1, 5, 1, @o1, @m1);
   
   -- Tab 2 (run at same time):
   CALL ProcessOrderWithLog(2, 5, 1, @o2, @m2);
   
   -- Check logs to see retry behavior
   SELECT * FROM RecentLogs WHERE Category = 'ORDER' ORDER BY LogTime DESC LIMIT 10;
   
9. View daily summary:
   SELECT * FROM DailySummary;
   
10. View inventory activity for a product:
    SELECT * FROM InventoryActivity WHERE ProductName LIKE '%USB%';
    
11. Test trigger-based logging:
    -- Update inventory directly (trigger should log it)
    UPDATE Inventory SET QuantityOnHand = QuantityOnHand + 50 WHERE ProductID = 1;
    SELECT * FROM InventoryActivity WHERE ProductID = 1 LIMIT 1;
    
    -- Update order status (trigger should log it)
    UPDATE Orders SET OrderStatus = 'Shipped' WHERE OrderID = 1;
    SELECT * FROM RecentLogs WHERE TableName = 'Orders' LIMIT 1;
    
    -- Update product price (trigger should log it)
    UPDATE Products SET Price = Price * 1.10 WHERE ProductID = 1;
    SELECT * FROM RecentLogs WHERE TableName = 'Products' LIMIT 1;
    
12. Simulate a rollback scenario:
    -- Try to order more than available (should rollback cleanly)
    SELECT QuantityOnHand FROM Inventory WHERE ProductID = 2;
    CALL ProcessOrderWithLog(1, 2, 999, @order, @msg);
    SELECT @msg;
    
    -- Verify inventory unchanged
    SELECT QuantityOnHand FROM Inventory WHERE ProductID = 2;
    
13. Clean old logs:
    CALL CleanOldLogs();
    SELECT * FROM RecentLogs WHERE Category = 'MAINTENANCE' LIMIT 1;
    
14. Generate a comprehensive test report:
    SELECT 
        'Test Report' AS Section,
        (SELECT COUNT(*) FROM SystemLog) AS TotalLogs,
        (SELECT COUNT(*) FROM OrderAuditLog WHERE Success = TRUE) AS SuccessfulOrders,
        (SELECT COUNT(*) FROM OrderAuditLog WHERE Success = FALSE) AS FailedOrders,
        (SELECT COUNT(*) FROM InventoryChangeLog) AS InventoryChanges,
        (SELECT COUNT(*) FROM SystemLog WHERE LogLevel = 'ERROR') AS Errors,
        (SELECT COUNT(*) FROM SystemLog WHERE LogLevel = 'WARNING') AS Warnings;

DETAILED RETRY TESTING:
========================

To test the retry mechanism with deadlocks, you would need concurrent transactions.
Here's a simplified test you can do manually:

-- Terminal 1:
START TRANSACTION;
SELECT * FROM Inventory WHERE ProductID = 5 FOR UPDATE;
-- Wait here, don't commit yet

-- Terminal 2 (while Terminal 1 is waiting):
CALL ProcessOrderWithLog(1, 5, 1, @order, @msg);
-- This will try to lock the same row, may trigger retry

-- Terminal 1 (now complete it):
COMMIT;

-- Check the logs:
SELECT * FROM RecentLogs WHERE Message LIKE '%Retry%' OR Message LIKE '%lock%';

ROLLBACK VERIFICATION:
======================

Verify that failed transactions don't leave partial data:

-- Before test
SELECT COUNT(*) AS OrdersBefore FROM Orders;
SELECT QuantityOnHand AS StockBefore FROM Inventory WHERE ProductID = 1;

-- Attempt invalid order
CALL ProcessOrderWithLog(1, 999, 5, @order, @msg);  -- Invalid product

-- After test (should be unchanged)
SELECT COUNT(*) AS OrdersAfter FROM Orders;
SELECT QuantityOnHand AS StockAfter FROM Inventory WHERE ProductID = 1;

-- Both should match the "Before" values
*/, v_Total, ' (Attempt ', v_RetryCount + 1, ')'));
            
            SET p_Message = CONCAT('Success: Order ', p_OrderID, ' created');
            
            -- Exit the retry loop
            LEAVE retry_loop;
        END;
        
        -- If we had a retryable error, wait briefly before retry
        IF v_ErrorCode IS NOT NULL AND v_RetryCount < v_MaxRetries THEN
            -- Small delay between retries (simulated with a dummy query)
            DO SLEEP(0.1);
        END IF;
        
    END WHILE retry_loop;
    
    -- If we exhausted retries without success
    IF v_Success = FALSE AND v_RetryCount >= v_MaxRetries THEN
        CALL LogEvent('ERROR', 'ORDER', CONCAT('Order failed after ', v_MaxRetries, ' retry attempts'));
        SET p_Message = CONCAT('Error: Order failed after ', v_MaxRetries, ' retry attempts');
        SET p_OrderID = NULL;
    END IF;
    
END//

DELIMITER ;

-- =====================================================
-- SIMPLE TRIGGERS FOR AUTO-LOGGING
-- =====================================================

DELIMITER //

-- Log order status changes
DROP TRIGGER IF EXISTS log_order_status//
CREATE TRIGGER log_order_status
AFTER UPDATE ON Orders
FOR EACH ROW
BEGIN
    IF OLD.OrderStatus != NEW.OrderStatus THEN
        INSERT INTO SystemLog (LogLevel, Category, Message, TableName, RecordID)
        VALUES ('INFO', 'ORDER', 
                CONCAT('Status changed: ', OLD.OrderStatus, ' -> ', NEW.OrderStatus),
                'Orders', NEW.OrderID);
    END IF;
END//

-- Log inventory updates
DROP TRIGGER IF EXISTS log_inventory_change//
CREATE TRIGGER log_inventory_change
AFTER UPDATE ON Inventory
FOR EACH ROW
BEGIN
    IF OLD.QuantityOnHand != NEW.QuantityOnHand THEN
        INSERT INTO InventoryChangeLog (ProductID, ChangeType, OldQty, NewQty, Reason)
        VALUES (NEW.ProductID, 'ADJUSTMENT', OLD.QuantityOnHand, NEW.QuantityOnHand, 'Direct update');
        
        INSERT INTO SystemLog (LogLevel, Category, Message, TableName, RecordID)
        VALUES ('INFO', 'INVENTORY', 
                CONCAT('Stock changed: ', OLD.QuantityOnHand, ' -> ', NEW.QuantityOnHand),
                'Inventory', NEW.ProductID);
    END IF;
END//

-- Log price changes
DROP TRIGGER IF EXISTS log_price_change//
CREATE TRIGGER log_price_change
AFTER UPDATE ON Products
FOR EACH ROW
BEGIN
    IF OLD.Price != NEW.Price THEN
        INSERT INTO SystemLog (LogLevel, Category, Message, TableName, RecordID)
        VALUES ('INFO', 'PRODUCT', 
                CONCAT('Price changed: $', OLD.Price, ' -> $', NEW.Price),
                'Products', NEW.ProductID);
    END IF;
END//

DELIMITER ;

-- =====================================================
-- SIMPLE VIEWS FOR EASY MONITORING
-- =====================================================

-- View all recent logs
CREATE OR REPLACE VIEW RecentLogs AS
SELECT 
    LogID,
    LogTime,
    LogLevel,
    Category,
    Message
FROM SystemLog
ORDER BY LogTime DESC
LIMIT 100;

-- View errors only
CREATE OR REPLACE VIEW ErrorLog AS
SELECT 
    LogID,
    LogTime,
    Category,
    Message,
    TableName,
    RecordID
FROM SystemLog
WHERE LogLevel = 'ERROR'
ORDER BY LogTime DESC;

-- View order activity
CREATE OR REPLACE VIEW OrderActivity AS
SELECT 
    a.LogTime,
    a.OrderID,
    a.CustomerID,
    a.ProductID,
    a.Action,
    a.Quantity,
    CASE WHEN a.Success THEN 'Success' ELSE 'Failed' END AS Status,
    a.ErrorMsg
FROM OrderAuditLog a
ORDER BY a.LogTime DESC;

-- View inventory activity
CREATE OR REPLACE VIEW InventoryActivity AS
SELECT 
    i.LogTime,
    p.ProductName,
    i.ChangeType,
    i.OldQty,
    i.NewQty,
    (i.NewQty - i.OldQty) AS Change,
    i.OrderID,
    i.Reason
FROM InventoryChangeLog i
JOIN Products p ON i.ProductID = p.ProductID
ORDER BY i.LogTime DESC;

-- Daily summary
CREATE OR REPLACE VIEW DailySummary AS
SELECT 
    DATE(LogTime) AS Date,
    COUNT(*) AS TotalLogs,
    SUM(CASE WHEN LogLevel = 'ERROR' THEN 1 ELSE 0 END) AS Errors,
    SUM(CASE WHEN LogLevel = 'WARNING' THEN 1 ELSE 0 END) AS Warnings,
    SUM(CASE WHEN LogLevel = 'INFO' THEN 1 ELSE 0 END) AS Info
FROM SystemLog
GROUP BY DATE(LogTime)
ORDER BY Date DESC;

-- =====================================================
-- SIMPLE MAINTENANCE
-- =====================================================

DELIMITER //

-- Clean old logs (keep last 30 days)
CREATE PROCEDURE CleanOldLogs()
BEGIN
    DECLARE rows_deleted INT;
    
    DELETE FROM SystemLog WHERE LogTime < DATE_SUB(NOW(), INTERVAL 30 DAY);
    SET rows_deleted = ROW_COUNT();
    
    INSERT INTO SystemLog (LogLevel, Category, Message)
    VALUES ('INFO', 'MAINTENANCE', CONCAT('Cleaned ', rows_deleted, ' old log entries'));
    
    DELETE FROM OrderAuditLog WHERE LogTime < DATE_SUB(NOW(), INTERVAL 30 DAY);
    DELETE FROM InventoryChangeLog WHERE LogTime < DATE_SUB(NOW(), INTERVAL 30 DAY);
END//

DELIMITER ;

-- =====================================================
-- INITIALIZATION AND TESTING
-- =====================================================

-- Log system startup
INSERT INTO SystemLog (LogLevel, Category, Message)
VALUES ('INFO', 'SYSTEM', 'Simple logging system initialized');

-- Show summary
SELECT 'Simple Logging System Ready' AS Status;

SELECT 
    'Logging Tables' AS Info,
    COUNT(*) AS TablesCreated 
FROM information_schema.tables 
WHERE table_schema = 'inventory_system' 
AND table_name IN ('SystemLog', 'OrderAuditLog', 'InventoryChangeLog');

-- =====================================================
-- QUICK TEST EXAMPLES
-- =====================================================

/*
TEST THE LOGGING SYSTEM:

1. Manual logging:
   CALL LogEvent('INFO', 'TEST', 'Testing the logging system');
   
2. Process an order with logging:
   CALL ProcessOrderWithLog(1, 2, 3, @order, @msg);
   SELECT @order AS OrderID, @msg AS Message;
   
3. View recent logs:
   SELECT * FROM RecentLogs LIMIT 20;
   
4. View errors only:
   SELECT * FROM ErrorLog;
   
5. View order activity:
   SELECT * FROM OrderActivity LIMIT 10;
   
6. View inventory changes:
   SELECT * FROM InventoryActivity LIMIT 10;
   
7. View daily summary:
   SELECT * FROM DailySummary;
   
8. Test error logging (invalid order):
   CALL ProcessOrderWithLog(999, 1, 5, @order, @msg);
   SELECT @order, @msg;
   SELECT * FROM ErrorLog LIMIT 1;
   
9. Test inventory trigger:
   UPDATE Inventory SET QuantityOnHand = QuantityOnHand + 10 WHERE ProductID = 1;
   SELECT * FROM InventoryActivity WHERE ProductID = 1 LIMIT 1;
   
10. Clean old logs:
    CALL CleanOldLogs();
*/