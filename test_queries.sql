-- TEST THE STORED PROCEDURE

-- Test 1: Successful order
CALL ProcessNewOrder(1, 2, 5, @order_id, @message);
SELECT @order_id AS OrderID, @message AS Message;

-- Verify the order was created
SELECT * FROM Orders WHERE OrderID = @order_id;
SELECT * FROM OrderItems WHERE OrderID = @order_id;

-- Check updated inventory
SELECT * FROM Inventory WHERE ProductID = 2;

-- Test 2: Insufficient stock (should fail)
CALL ProcessNewOrder(2, 1, 500, @order_id2, @message2);
SELECT @order_id2 AS OrderID, @message2 AS Message;


-- Test 3: Invalid customer (should fail)
CALL ProcessNewOrder(9999, 3, 1, @order_id3, @message3);
SELECT @order_id3 AS OrderID, @message3 AS Message;


-- Test the view
SELECT * FROM ProductInventoryStatus WHERE StockStatus = 'Low Stock';

-- Test the view
SELECT * FROM CustomerSalesSummary ORDER BY TotalAmountSpent DESC LIMIT 10;

-- Testing UpdateOrderStatus procedure
CALL UpdateOrderStatus(@order_id, 'Shipped', @update_message);
SELECT @update_message AS UpdateMessage;



-- Log queries
-- Manual logging of system events:
   CALL LogSystemEvent('INFO', 'CUSTOM_EVENT', 'Your message here', 'TableName', RecordID, NULL);

-- Processing an order with full logging:
   CALL ProcessNewOrderWithLogging(1, 5, 2, @order_id, @message);
   SELECT @order_id, @message;


-- View order processing performance:
   SELECT * FROM OrderProcessingSummary;

-- View inventory changes:
   SELECT * FROM InventoryChangeSummary;

-- View system health:
   SELECT * FROM SystemHealthLog WHERE LogDate >= DATE_SUB(CURDATE(), INTERVAL 7 DAY);

-- Generate daily report:
   CALL GenerateDailySummaryReport(CURDATE());

-- Archive old logs (keep last 90 days):
   CALL ArchiveOldLogs(90);

-- Query specific error types:
   SELECT * FROM SystemLog 
   WHERE LogCategory = 'ORDER_PROCESSING' 
   AND LogLevel = 'ERROR' 
   ORDER BY LogTimestamp DESC;

-- Monitor slow queries:
    SELECT * FROM QueryPerformanceLog 
    WHERE ExecutionTimeMs > 1000 
    ORDER BY ExecutionTimeMs DESC;
