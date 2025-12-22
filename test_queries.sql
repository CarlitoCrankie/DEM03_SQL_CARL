-- TEST THE STORED PROCEDURE AND VIEWS

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
   SELECT * FROM OrderActivity WHERE OrderID = @order;

-- 3. Test insufficient stock:
   CALL ProcessOrderWithLog(1, 2, -5, @order, @msg);
   SELECT @order,@msg;
   SELECT * FROM ErrorLog LIMIT 5;
   SELECT * FROM orderactivity WHERE 'Success' = FALSE LIMIT 1;

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