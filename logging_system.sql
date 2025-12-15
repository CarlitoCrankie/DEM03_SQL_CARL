-- LOGGING SYSTEM FOR INVENTORY MANAGEMENT
-- for tracking all database operations, errors, and processes


-- Main system log table
CREATE TABLE IF NOT EXISTS SystemLog (
    LogID INT PRIMARY KEY AUTO_INCREMENT,
    LogTimestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LogLevel ENUM('INFO', 'WARNING', 'ERROR', 'DEBUG', 'CRITICAL') NOT NULL,
    LogCategory VARCHAR(50) NOT NULL,
    LogMessage TEXT NOT NULL,
    UserContext VARCHAR(100),
    IPAddress VARCHAR(45),
    AffectedTable VARCHAR(50),
    AffectedRecordID INT,
    SQLQuery TEXT,
    ErrorCode VARCHAR(10),
    StackTrace TEXT,
    INDEX idx_timestamp (LogTimestamp),
    INDEX idx_level (LogLevel),
    INDEX idx_category (LogCategory)
) ENGINE=InnoDB;

-- Order processing audit log
CREATE TABLE IF NOT EXISTS OrderAuditLog (
    AuditID INT PRIMARY KEY AUTO_INCREMENT,
    OrderID INT,
    CustomerID INT,
    ProductID INT,
    ActionType ENUM('CREATE', 'UPDATE', 'DELETE', 'CANCEL') NOT NULL,
    ActionTimestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    OldValue TEXT,
    NewValue TEXT,
    QuantityChanged INT,
    InventoryBefore INT,
    InventoryAfter INT,
    Success BOOLEAN NOT NULL,
    ErrorMessage TEXT,
    ProcessingTimeMs INT,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID) ON DELETE SET NULL,
    INDEX idx_order (OrderID),
    INDEX idx_timestamp (ActionTimestamp)
) ENGINE=InnoDB;

-- Inventory change log
CREATE TABLE IF NOT EXISTS InventoryChangeLog (
    ChangeID INT PRIMARY KEY AUTO_INCREMENT,
    ProductID INT NOT NULL,
    ChangeTimestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ChangeType ENUM('SALE', 'RESTOCK', 'ADJUSTMENT', 'RETURN') NOT NULL,
    QuantityBefore INT NOT NULL,
    QuantityAfter INT NOT NULL,
    QuantityChanged INT NOT NULL,
    RelatedOrderID INT,
    Reason TEXT,
    PerformedBy VARCHAR(100),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    INDEX idx_product (ProductID),
    INDEX idx_timestamp (ChangeTimestamp)
) ENGINE=InnoDB;

-- Query performance log
CREATE TABLE IF NOT EXISTS QueryPerformanceLog (
    PerformanceID INT PRIMARY KEY AUTO_INCREMENT,
    QueryName VARCHAR(100) NOT NULL,
    ExecutionTimestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ExecutionTimeMs DECIMAL(10,2) NOT NULL,
    RowsAffected INT,
    QueryType ENUM('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'PROCEDURE') NOT NULL,
    Success BOOLEAN NOT NULL,
    ErrorMessage TEXT,
    INDEX idx_query_name (QueryName),
    INDEX idx_timestamp (ExecutionTimestamp)
) ENGINE=InnoDB;

-- User activity log
CREATE TABLE IF NOT EXISTS UserActivityLog (
    ActivityID INT PRIMARY KEY AUTO_INCREMENT,
    ActivityTimestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UserName VARCHAR(100),
    ActivityType VARCHAR(50) NOT NULL,
    Description TEXT,
    IPAddress VARCHAR(45),
    SessionID VARCHAR(100),
    INDEX idx_user (UserName),
    INDEX idx_timestamp (ActivityTimestamp)
) ENGINE=InnoDB;


-- LOGGING STORED PROCEDURES
DELIMITER //

-- Procedure to log general system events
CREATE PROCEDURE LogSystemEvent(
    IN p_LogLevel VARCHAR(20),
    IN p_Category VARCHAR(50),
    IN p_Message TEXT,
    IN p_AffectedTable VARCHAR(50),
    IN p_AffectedRecordID INT,
    IN p_ErrorCode VARCHAR(10)
)
BEGIN
    INSERT INTO SystemLog (
        LogLevel, 
        LogCategory, 
        LogMessage, 
        AffectedTable, 
        AffectedRecordID, 
        ErrorCode
    )
    VALUES (
        p_LogLevel, 
        p_Category, 
        p_Message, 
        p_AffectedTable, 
        p_AffectedRecordID, 
        p_ErrorCode
    );
END//

-- Procedure to log inventory changes
CREATE PROCEDURE LogInventoryChange(
    IN p_ProductID INT,
    IN p_ChangeType VARCHAR(20),
    IN p_QuantityBefore INT,
    IN p_QuantityAfter INT,
    IN p_RelatedOrderID INT,
    IN p_Reason TEXT
)
BEGIN
    DECLARE v_QuantityChanged INT;
    SET v_QuantityChanged = p_QuantityAfter - p_QuantityBefore;
    
    INSERT INTO InventoryChangeLog (
        ProductID,
        ChangeType,
        QuantityBefore,
        QuantityAfter,
        QuantityChanged,
        RelatedOrderID,
        Reason
    )
    VALUES (
        p_ProductID,
        p_ChangeType,
        p_QuantityBefore,
        p_QuantityAfter,
        v_QuantityChanged,
        p_RelatedOrderID,
        p_Reason
    );
END//

-- Procedure to log query performance
CREATE PROCEDURE LogQueryPerformance(
    IN p_QueryName VARCHAR(100),
    IN p_ExecutionTimeMs DECIMAL(10,2),
    IN p_RowsAffected INT,
    IN p_QueryType VARCHAR(20),
    IN p_Success BOOLEAN,
    IN p_ErrorMessage TEXT
)
BEGIN
    INSERT INTO QueryPerformanceLog (
        QueryName,
        ExecutionTimeMs,
        RowsAffected,
        QueryType,
        Success,
        ErrorMessage
    )
    VALUES (
        p_QueryName,
        p_ExecutionTimeMs,
        p_RowsAffected,
        p_QueryType,
        p_Success,
        p_ErrorMessage
    );
END//

DELIMITER;



-- ENHANCED PROCESSORDER WITH LOGGING
DELIMITER //

DROP PROCEDURE IF EXISTS ProcessNewOrderWithLogging;

CREATE PROCEDURE ProcessNewOrderWithLogging(
    IN p_CustomerID INT,
    IN p_ProductID INT,
    IN p_Quantity INT,
    OUT p_OrderID INT,
    OUT p_Message VARCHAR(255)
)
proc: BEGIN
    DECLARE v_QuantityOnHand INT;
    DECLARE v_ProductPrice DECIMAL(10, 2);
    DECLARE v_TotalAmount DECIMAL(10, 2);
    DECLARE v_OrderExists INT DEFAULT 0;
    DECLARE v_StartTime TIMESTAMP;
    DECLARE v_EndTime TIMESTAMP;
    DECLARE v_ExecutionTimeMs INT;
    DECLARE v_ProductName VARCHAR(150);
    
    -- Record start time
    SET v_StartTime = NOW(3);
    
    -- Log procedure start
    CALL LogSystemEvent('INFO', 'ORDER_PROCESSING', 
        CONCAT('Starting order process for CustomerID: ', p_CustomerID, 
               ', ProductID: ', p_ProductID, ', Quantity: ', p_Quantity),
        'Orders', NULL, NULL
        );
        
    -- Error handler for any SQL errors
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_Message = 'Error: Transaction failed and was rolled back.';
        SET p_OrderID = NULL;
    END;
        
        -- Calculate execution time
        SET v_EndTime = NOW(3);
        SET v_ExecutionTimeMs = TIMESTAMPDIFF(MICROSECOND, v_StartTime, v_EndTime) / 1000;
        
        -- Log error
        CALL LogSystemEvent('ERROR', 'ORDER_PROCESSING', 
            'Transaction failed and was rolled back',
            'Orders', NULL, SQLSTATE);
            
        -- Log audit trail
        INSERT INTO OrderAuditLog (
            OrderID, CustomerID, ProductID, ActionType, 
            Success, ErrorMessage, ProcessingTimeMs
        )
        VALUES (
            NULL, p_CustomerID, p_ProductID, 'CREATE',
            FALSE, 'SQL Exception occurred', v_ExecutionTimeMs
        );
        
        SET p_Message = 'Error: Transaction failed and was rolled back.';
        SET p_OrderID = NULL;
    END;
    
        -- Guard: quantity must be positive
    IF p_Quantity IS NULL OR p_Quantity <= 0 THEN
        CALL LogSystemEvent(
            'WARNING', 'ORDER_PROCESSING',
            CONCAT('Invalid quantity: ', COALESCE(p_Quantity, 0)),
            'Orders', NULL, 'BAD_QUANTITY'
        );
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
        CALL LogSystemEvent('WARNING', 'ORDER_PROCESSING', 
            CONCAT('Customer ID ', p_CustomerID, ' does not exist'),
            'Customers', p_CustomerID, 'CUST_NOT_FOUND');
            
        SET p_Message = 'Error: Customer ID does not exist.';
        SET p_OrderID = NULL;
        ROLLBACK;
        LEAVE proc;
    END IF;
    
	-- Check if product exists and get details
	SELECT Price, ProductName INTO v_ProductPrice, v_ProductName
	FROM Products
	WHERE ProductID = p_ProductID;
        
	IF v_ProductPrice IS NULL THEN
		CALL LogSystemEvent('WARNING', 'ORDER_PROCESSING', 
			CONCAT('Product ID ', p_ProductID, ' does not exist'),
			'Products', p_ProductID, 'PROD_NOT_FOUND');
                
		SET p_Message = 'Error: Product ID does not exist.';
		SET p_OrderID = NULL;
		ROLLBACK;
        LEAVE proc;
	END IF;
    
	-- Check inventory
	SELECT QuantityOnHand INTO v_QuantityOnHand
	FROM Inventory
	WHERE ProductID = p_ProductID;
            
	IF v_QuantityOnHand IS NULL THEN
		CALL LogSystemEvent('WARNING', 'ORDER_PROCESSING', 
			CONCAT('Product ID ', p_ProductID, ' not found in inventory'),
			'Inventory', p_ProductID, 'INV_NOT_FOUND');
                    
		SET p_Message = 'Error: Product not found in inventory.';
		SET p_OrderID = NULL;
		ROLLBACK;
        LEAVE proc;
	ELSEIF v_QuantityOnHand < p_Quantity THEN
			CALL LogSystemEvent('WARNING', 'ORDER_PROCESSING', 
				CONCAT('Insufficient stock for Product ID ', p_ProductID, 
					'. Requested: ', p_Quantity, ', Available: ', v_QuantityOnHand),
				'Inventory', p_ProductID, 'INSUFFICIENT_STOCK');
                    
			SET p_Message = CONCAT('Error: Insufficient stock. Available: ', v_QuantityOnHand);
			SET p_OrderID = NULL;
			ROLLBACK;
	END IF;
    
	-- Calculate total amount
	SET v_TotalAmount = v_ProductPrice * p_Quantity;
                
	-- Create new order
	INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, OrderStatus)
	VALUES (p_CustomerID, CURDATE(), v_TotalAmount, 'Pending');
                
	SET p_OrderID = LAST_INSERT_ID();
                
	-- Log order creation
	CALL LogSystemEvent('INFO', 'ORDER_PROCESSING', 
		CONCAT('Order ', p_OrderID, ' created successfully. Amount: $', v_TotalAmount),
		'Orders', p_OrderID, NULL);
                
	-- Create order item
	INSERT INTO OrderItems (OrderID, ProductID, Quantity, PriceAtPurchase)
	VALUES (p_OrderID, p_ProductID, p_Quantity, v_ProductPrice);
                
	-- Log inventory change
	CALL LogInventoryChange(
		p_ProductID,
        'SALE',
        v_QuantityOnHand,
		v_QuantityOnHand - p_Quantity,
		p_OrderID,
        CONCAT('Order #', p_OrderID, ' - Sold ', p_Quantity, ' units of ', v_ProductName)
);
                
	-- Update inventory
	UPDATE Inventory
	SET QuantityOnHand = QuantityOnHand - p_Quantity
	WHERE ProductID = p_ProductID;
                
	-- Calculate execution time
	SET v_EndTime = NOW(3);
	SET v_ExecutionTimeMs = TIMESTAMPDIFF(MICROSECOND, v_StartTime, v_EndTime) / 1000;
                
	-- Log audit trail
	INSERT INTO OrderAuditLog (
			OrderID, CustomerID, ProductID, ActionType,
			QuantityChanged, InventoryBefore, InventoryAfter,
			Success, ProcessingTimeMs
		)
		VALUES (
			p_OrderID, p_CustomerID, p_ProductID, 'CREATE',
			p_Quantity, v_QuantityOnHand, v_QuantityOnHand - p_Quantity,
			TRUE, v_ExecutionTimeMs
		);
                
	-- Log performance
    CALL LogQueryPerformance(
        'ProcessNewOrderWithLogging',
        v_ExecutionTimeMs,
        3,
        'PROCEDURE',
        TRUE,
        NULL
    );

    -- Commit transaction
    COMMIT;

    SET p_Message = CONCAT('Success: Order ', p_OrderID, ' created successfully.');

    -- Log final success
    CALL LogSystemEvent(
        'INFO', 'ORDER_PROCESSING',
        CONCAT('Order processing completed successfully. OrderID: ', p_OrderID,
               ', Execution time: ', v_ExecutionTimeMs, 'ms'),
        'Orders', p_OrderID, NULL
    );
END //

DELIMITER;


-- TRIGGERS FOR AUTOMATIC LOGGING
DELIMITER //

-- Trigger to log all order insertions
CREATE TRIGGER after_order_insert
AFTER INSERT ON Orders
FOR EACH ROW
BEGIN
    CALL LogSystemEvent('INFO', 'ORDER_CREATED', 
        CONCAT('New order created. OrderID: ', NEW.OrderID, 
               ', CustomerID: ', NEW.CustomerID, 
               ', Amount: $', NEW.TotalAmount),
        'Orders', NEW.OrderID, NULL);
END//

-- Trigger to log order status changes

CREATE TRIGGER after_order_update
AFTER UPDATE ON Orders
FOR EACH ROW
BEGIN
    IF OLD.OrderStatus != NEW.OrderStatus THEN
        CALL LogSystemEvent('INFO', 'ORDER_STATUS_CHANGE', 
            CONCAT('Order status changed. OrderID: ', NEW.OrderID, 
                   ', Old Status: ', OLD.OrderStatus, 
                   ', New Status: ', NEW.OrderStatus),
            'Orders', NEW.OrderID, NULL);
    END IF;
    
    IF OLD.TotalAmount != NEW.TotalAmount THEN
        CALL LogSystemEvent('INFO', 'ORDER_AMOUNT_CHANGE', 
            CONCAT('Order amount changed. OrderID: ', NEW.OrderID, 
                   ', Old Amount: $', OLD.TotalAmount, 
                   ', New Amount: $', NEW.TotalAmount),
            'Orders', NEW.OrderID, NULL);
    END IF;
END//

-- Trigger to log inventory updates
CREATE TRIGGER after_inventory_update
AFTER UPDATE ON Inventory
FOR EACH ROW
BEGIN
    IF OLD.QuantityOnHand != NEW.QuantityOnHand THEN
        INSERT INTO InventoryChangeLog (
            ProductID, ChangeType, QuantityBefore, QuantityAfter, 
            QuantityChanged, Reason
        )
        VALUES (
            NEW.ProductID, 'ADJUSTMENT', OLD.QuantityOnHand, NEW.QuantityOnHand,
            NEW.QuantityOnHand - OLD.QuantityOnHand,
            'Direct inventory update'
        );
        
        CALL LogSystemEvent('INFO', 'INVENTORY_UPDATE', 
            CONCAT('Inventory updated. ProductID: ', NEW.ProductID, 
                   ', Old Quantity: ', OLD.QuantityOnHand, 
                   ', New Quantity: ', NEW.QuantityOnHand),
            'Inventory', NEW.ProductID, NULL);
    END IF;
END//

-- Trigger to log product price changes
CREATE TRIGGER after_product_update
AFTER UPDATE ON Products
FOR EACH ROW
BEGIN
    IF OLD.Price != NEW.Price THEN
        CALL LogSystemEvent('INFO', 'PRICE_CHANGE', 
            CONCAT('Product price changed. ProductID: ', NEW.ProductID, 
                   ', Product: ', NEW.ProductName,
                   ', Old Price: $', OLD.Price, 
                   ', New Price: $', NEW.Price),
            'Products', NEW.ProductID, NULL);
    END IF;
END//

DELIMITER ;


-- VIEWS FOR LOG ANALYSIS

-- View for recent errors
CREATE OR REPLACE VIEW RecentErrors AS
SELECT 
    LogID,
    LogTimestamp,
    LogCategory,
    LogMessage,
    AffectedTable,
    AffectedRecordID,
    ErrorCode
FROM SystemLog
WHERE LogLevel IN ('ERROR', 'CRITICAL')
ORDER BY LogTimestamp DESC;

-- View for order processing summary
CREATE OR REPLACE VIEW OrderProcessingSummary AS
SELECT 
    DATE(ActionTimestamp) AS ProcessingDate,
    COUNT(*) AS TotalAttempts,
    SUM(CASE WHEN Success = TRUE THEN 1 ELSE 0 END) AS SuccessfulOrders,
    SUM(CASE WHEN Success = FALSE THEN 1 ELSE 0 END) AS FailedOrders,
    AVG(ProcessingTimeMs) AS AvgProcessingTimeMs,
    MAX(ProcessingTimeMs) AS MaxProcessingTimeMs
FROM OrderAuditLog
GROUP BY DATE(ActionTimestamp)
ORDER BY ProcessingDate DESC;

-- View for inventory changes summary
CREATE OR REPLACE VIEW InventoryChangeSummary AS
SELECT 
    p.ProductID,
    p.ProductName,
    p.Category,
    COUNT(icl.ChangeID) AS TotalChanges,
    SUM(CASE WHEN icl.ChangeType = 'SALE' THEN ABS(icl.QuantityChanged) ELSE 0 END) AS TotalSold,
    SUM(CASE WHEN icl.ChangeType = 'RESTOCK' THEN icl.QuantityChanged ELSE 0 END) AS TotalRestocked,
    i.QuantityOnHand AS CurrentStock
FROM Products p
LEFT JOIN InventoryChangeLog icl ON p.ProductID = icl.ProductID
LEFT JOIN Inventory i ON p.ProductID = i.ProductID
GROUP BY p.ProductID, p.ProductName, p.Category, i.QuantityOnHand
ORDER BY TotalSold DESC;

-- View for system health monitoring
CREATE OR REPLACE VIEW SystemHealthLog AS
SELECT 
    DATE(LogTimestamp) AS LogDate,
    COUNT(*) AS TotalLogs,
    SUM(CASE WHEN LogLevel = 'ERROR' THEN 1 ELSE 0 END) AS ErrorCount,
    SUM(CASE WHEN LogLevel = 'WARNING' THEN 1 ELSE 0 END) AS WarningCount,
    SUM(CASE WHEN LogLevel = 'INFO' THEN 1 ELSE 0 END) AS InfoCount,
    SUM(CASE WHEN LogLevel = 'CRITICAL' THEN 1 ELSE 0 END) AS CriticalCount
FROM SystemLog
GROUP BY DATE(LogTimestamp)
ORDER BY LogDate DESC;


-- LOG MAINTENANCE PROCEDURES
DELIMITER //

-- Procedure to archive old logs
CREATE PROCEDURE ArchiveOldLogs(IN p_DaysToKeep INT)
BEGIN
    DECLARE v_CutoffDate DATE;
    DECLARE v_RowsDeleted INT;
    
    SET v_CutoffDate = DATE_SUB(CURDATE(), INTERVAL p_DaysToKeep DAY);
    
    -- Archive and delete old system logs
    DELETE FROM SystemLog WHERE LogTimestamp < v_CutoffDate;
    SET v_RowsDeleted = ROW_COUNT();
    
    CALL LogSystemEvent('INFO', 'LOG_MAINTENANCE', 
        CONCAT('Archived and deleted ', v_RowsDeleted, ' old system log entries'),
        'SystemLog', NULL, NULL);
    
    -- Archive and delete old audit logs
    DELETE FROM OrderAuditLog WHERE ActionTimestamp < v_CutoffDate;
    SET v_RowsDeleted = ROW_COUNT();
    
    CALL LogSystemEvent('INFO', 'LOG_MAINTENANCE', 
        CONCAT('Archived and deleted ', v_RowsDeleted, ' old order audit log entries'),
        'OrderAuditLog', NULL, NULL);
        
    -- Archive and delete old inventory change logs
    DELETE FROM InventoryChangeLog WHERE ChangeTimestamp < v_CutoffDate;
    SET v_RowsDeleted = ROW_COUNT();
    
    CALL LogSystemEvent('INFO', 'LOG_MAINTENANCE', 
        CONCAT('Archived and deleted ', v_RowsDeleted, ' old inventory change log entries'),
        'InventoryChangeLog', NULL, NULL);
END//

-- Procedure to generate daily summary report
CREATE PROCEDURE GenerateDailySummaryReport(IN p_ReportDate DATE)
BEGIN
    SELECT 
        'DAILY SYSTEM SUMMARY REPORT' AS ReportType,
        p_ReportDate AS ReportDate;
    
    -- Order statistics
    SELECT 
        'Order Statistics' AS Section,
        COUNT(*) AS TotalOrders,
        SUM(CASE WHEN Success = TRUE THEN 1 ELSE 0 END) AS SuccessfulOrders,
        SUM(CASE WHEN Success = FALSE THEN 1 ELSE 0 END) AS FailedOrders,
        CONCAT(AVG(ProcessingTimeMs), ' ms') AS AvgProcessingTime
    FROM OrderAuditLog
    WHERE DATE(ActionTimestamp) = p_ReportDate;
    
    -- System log statistics
    SELECT 
        'System Log Statistics' AS Section,
        LogLevel,
        COUNT(*) AS Count
    FROM SystemLog
    WHERE DATE(LogTimestamp) = p_ReportDate
    GROUP BY LogLevel;
    
    -- Top errors
    SELECT 
        'Top Errors' AS Section,
        LogCategory,
        COUNT(*) AS ErrorCount,
        LogMessage
    FROM SystemLog
    WHERE DATE(LogTimestamp) = p_ReportDate
      AND LogLevel = 'ERROR'
    GROUP BY LogCategory, LogMessage
    ORDER BY ErrorCount DESC
    LIMIT 5;
END//

DELIMITER ;


-- INITIALIZATION AND TESTING

-- Log system initialization
CALL LogSystemEvent('INFO', 'SYSTEM_INIT', 
    'Logging system initialized successfully', NULL, NULL, NULL);

-- Test the logging system
CALL LogSystemEvent('DEBUG', 'SYSTEM_TEST', 
    'Testing logging system functionality', NULL, NULL, NULL);

-- Display logging system status
SELECT 'Logging System Initialized Successfully' AS Status;
SELECT COUNT(*) AS LoggingTablesCreated FROM information_schema.tables 
WHERE table_schema = 'inventory_system' 
AND table_name IN ('SystemLog', 'OrderAuditLog', 'InventoryChangeLog', 
                   'QueryPerformanceLog', 'UserActivityLog');
