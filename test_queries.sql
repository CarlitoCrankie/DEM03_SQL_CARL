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
SELECT * FROM productinventorystatus WHERE StockStatus = 'Low Stock'

-- Test the view
SELECT * FROM CustomerSalesSummary ORDER BY TotalAmountSpent DESC LIMIT 10;

-- Testing UpdateOrderStatus procedure
CALL UpdateOrderStatus(@order_id, 'Shipped', @update_message);
SELECT @update_message AS UpdateMessage;


-- 1. Test logging:
   CALL LogEvent('INFO', 'TEST', 'Hello logging!');
   SELECT * FROM RecentLogs LIMIT 5;

-- 2. Process successful order:
   CALL ProcessOrderWithLog(1, 2, 2, @order, @msg);
   SELECT @order, @msg;
   SELECT * FROM OrderActivity LIMIT 5;

-- 3. Test insufficient stock:
   CALL ProcessOrderWithLog(1, 1, 9999, @order, @msg);
   SELECT @msg;
   SELECT * FROM ErrorLog LIMIT 1;

-- 4. Test order cancellation:
   CALL ProcessOrderWithLog(2, 3, 2, @order, @msg);
   SELECT QuantityOnHand FROM Inventory WHERE ProductID = 3;
   CALL CancelOrder(@order, 'Test cancellation', @cancel_msg);
   SELECT QuantityOnHand FROM Inventory WHERE ProductID = 3;

-- 5. View all activity:
   SELECT * FROM RecentLogs LIMIT 20;
   SELECT * FROM DailySummary;

-- TEST NEW LOGGING-ENABLED PROCEDURES

-- Test 1: Process order with logging
CALL ProcessOrderWithLog(1, 2, 3, @order_id, @message);
SELECT @order_id AS OrderID, @message AS StatusMessage;

-- Test 2: View the logs
SELECT * FROM RecentLogs LIMIT 10;

-- Test 3: View order activity
SELECT * FROM OrderActivity LIMIT 5;

-- Test 4: Cancel an order
CALL CancelOrder(@order_id, 'Testing cancellation', @cancel_msg);
SELECT @cancel_msg AS CancellationResult;

-- Test 5: Verify inventory restored
SELECT * FROM InventoryActivity WHERE OrderID = @order_id;