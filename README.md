# Inventory and Order Management System

## Project Overview
A comprehensive SQL database implementation for an e-commerce inventory and order management system. This project demonstrates database design and normalization (3NF), advanced SQL querying techniques, window functions, stored procedures, and business analytics through Key Performance Indicators (KPIs).

This capstone project encompasses the complete database development lifecycle from initial schema design to complex analytical query implementation.

---

## Database Schema

### Tables
The database consists of five normalized tables designed to eliminate data redundancy and maintain referential integrity:

1. **Customers** - Stores customer information including contact details and shipping addresses
2. **Products** - Contains product catalog with categories and pricing information
3. **Inventory** - Tracks real-time stock levels for each product
4. **Orders** - Maintains order headers with customer references, dates, totals, and status
5. **OrderItems** - Bridge table implementing the many-to-many relationship between orders and products

### Entity Relationships
- Customers to Orders: One-to-Many relationship
- Orders to OrderItems: One-to-Many relationship
- Products to OrderItems: One-to-Many relationship
- Products to Inventory: One-to-One relationship

---

## Project Deliverables

### 1. DDL_Schema.sql
Database schema implementation script containing:
- CREATE TABLE statements for all five tables
- Primary key constraints on all ID fields
- Foreign key constraints establishing table relationships
- CHECK constraints ensuring data integrity (non-negative prices and quantities)
- NOT NULL constraints on essential fields
- UNIQUE constraint on customer email addresses
- Performance indexes on frequently queried columns
- Sample data INSERT statements for testing and demonstration

### 2. DML_Queries.sql
Comprehensive query implementation script containing:

**Business KPI Queries:**
- Total Revenue Calculation: Aggregates revenue from completed orders
- Top 10 Customers: Ranks customers by total spending with order counts
- Best-Selling Products: Identifies top 5 products by quantity sold
- Monthly Sales Trend: Analyzes revenue patterns across time periods

**Analytical Queries with Window Functions:**
- Sales Rank by Category: Implements RANK(), DENSE_RANK(), and ROW_NUMBER() with PARTITION BY to rank products within each category
- Customer Order Frequency: Uses LAG() and LEAD() window functions to analyze customer purchase patterns and calculate time between orders

**Performance Optimization:**
- CustomerSalesSummary View: Pre-aggregated customer analytics for improved query performance
- ProductInventoryStatus View: Consolidated product and inventory information with stock status indicators
- ProcessNewOrder Stored Procedure: Complete order processing with transaction management, inventory validation, and error handling

### 3. Logging_System.sql
Comprehensive logging infrastructure for error tracking, audit trails, and debugging:

**Logging Tables:**
- SystemLog: Primary log table for all system events, errors, and warnings
- OrderAuditLog: Complete audit trail for order processing transactions
- InventoryChangeLog: Tracks all inventory modifications with change history

**Logging Procedures:**
- LogSystemEvent: General-purpose event logging
- LogInventoryChange: Specialized inventory change tracking 
- ProcessNewOrderWithLogging: Enhanced order processing with full logging
- GenerateDailySummaryReport: Daily system activity reporting

**Automatic Triggers:**
- after_order_insert: Logs order creation events
- after_order_update: Tracks order status and amount changes
- after_inventory_update: Records inventory level modifications
- after_product_update: Logs product price changes

**Analytical Views:**
- RecentErrors: Quick access to recent error entries
- OrderProcessingSummary: Aggregated order processing statistics
- InventoryChangeSummary: Inventory change analytics by product
- SystemHealthLog: System health metrics and error tracking

### 4. ERD Diagram
Entity-Relationship Diagram providing visual representation of the database structure, including all tables, attributes, primary keys, foreign keys, and relationship cardinalities.

---

## Prerequisites

### Software Requirements
- MySQL Server 8.0 or higher (recommended) or MySQL 9.x
- MySQL Workbench 8.0 or higher, or any MySQL-compatible SQL client
- Alternative: XAMPP (includes MySQL Server and phpMyAdmin)

### System Requirements
- Operating System: Windows 10/11, macOS, or Linux
- Minimum RAM: 4GB
- Disk Space: 500MB for MySQL installation
- Network: Local network access for database connections

---

## Installation and Setup

### Step 1: Install MySQL Server

**Option A: Standalone MySQL Installation**
1. Download MySQL Community Server from https://dev.mysql.com/downloads/mysql/
2. Select version 8.0.x for stability
3. Choose ZIP Archive for Windows or appropriate package for your OS
4. Extract to a suitable directory (e.g., C:\mysql\)
5. Initialize the database:
   ```
   cd [mysql-directory]\bin
   mysqld --initialize-insecure --console
   ```
6. Install as a service:
   ```
   mysqld --install
   net start mysql
   ```
7. Set root password:
   ```
   mysql -u root
   ALTER USER 'root'@'localhost' IDENTIFIED BY 'your_password';
   FLUSH PRIVILEGES;
   exit;
   ```

**Option B: XAMPP Installation (Recommended for ease of use)**
1. Download XAMPP from https://www.apachefriends.org/download.html
2. Install with MySQL component selected
3. Launch XAMPP Control Panel
4. Start MySQL service
5. Default credentials: username 'root', no password

### Step 2: Install MySQL Workbench
1. Download MySQL Workbench from https://dev.mysql.com/downloads/workbench/
2. Install following the setup wizard
3. Launch MySQL Workbench
4. Create a new connection:
   - Connection Name: Local MySQL
   - Hostname: localhost
   - Port: 3306
   - Username: root
   - Password: (as configured in Step 1)
5. Test the connection to verify successful setup

### Step 3: Create Database
Execute the following SQL commands to create the database:
```sql
CREATE DATABASE inventory_system;
USE inventory_system;
```

### Step 4: Execute DDL Script
1. Open MySQL Workbench and connect to your database
2. Select File > Open SQL Script
3. Navigate to and select DDL_Schema.sql
4. Execute the entire script (lightning bolt icon or Ctrl+Shift+Enter)
5. Verify successful execution by checking for:
   - All 5 tables created
   - Sample data inserted (12 customers, 15 products, 17 orders)
   - No error messages in the output panel

### Step 5: Execute DML Script
1. In MySQL Workbench, select File > Open SQL Script
2. Navigate to and select DML_Queries.sql
3. Execute the entire script
4. Review the query results in the output panels:
   - KPI metrics and reports
   - Window function demonstrations
   - View creation confirmations
   - Stored procedure test results

### Step 6: Execute Logging System Script (Optional but Recommended)
1. In MySQL Workbench, select File > Open SQL Script
2. Navigate to and select Logging_System.sql
3. Execute the entire script
4. Verify logging system installation:
   ```sql
   SHOW TABLES LIKE '%Log';
   SELECT COUNT(*) FROM SystemLog;
   ```
5. Test logging functionality:
   ```sql
   CALL LogSystemEvent('INFO', 'TEST', 'Testing logging system', NULL, NULL, NULL);
   SELECT * FROM SystemLog ORDER BY LogTimestamp DESC LIMIT 1;
   ```

**Note:** The logging system is optional but highly recommended for production environments. It provides comprehensive error tracking, audit trails, and debugging capabilities.

---

## Creating the ERD Diagram

### Using dbdiagram.io (Recommended)
1. Navigate to https://dbdiagram.io
2. Click "Go to App"
3. Clear the default sample code
4. Paste the following schema definition:

```
Table Customers {
  CustomerID int [pk, increment]
  FullName varchar(100) [not null]
  Email varchar(100) [not null, unique]
  Phone varchar(20)
  ShippingAddress varchar(255) [not null]
}

Table Products {
  ProductID int [pk, increment]
  ProductName varchar(150) [not null]
  Category varchar(50) [not null]
  Price decimal(10,2) [not null]
  
  Note: 'Price must be non-negative'
}

Table Inventory {
  ProductID int [pk, ref: - Products.ProductID]
  QuantityOnHand int [not null, default: 0]
  
  Note: 'QuantityOnHand must be non-negative'
}

Table Orders {
  OrderID int [pk, increment]
  CustomerID int [not null, ref: > Customers.CustomerID]
  OrderDate date [not null]
  TotalAmount decimal(10,2) [not null]
  OrderStatus varchar(20) [not null, default: 'Pending']
  
  Note: 'OrderStatus: Pending, Shipped, Delivered'
}

Table OrderItems {
  OrderItemID int [pk, increment]
  OrderID int [not null, ref: > Orders.OrderID]
  ProductID int [not null, ref: > Products.ProductID]
  Quantity int [not null]
  PriceAtPurchase decimal(10,2) [not null]
  
  Note: 'Quantity and PriceAtPurchase must be positive'
}
```

5. The diagram will automatically generate showing all relationships
6. Export the diagram: Click Export > Export to PNG
7. Save as ERD_Diagram.png

### Using MySQL Workbench
1. In MySQL Workbench, select Database > Reverse Engineer
2. Select your connection and click Continue
3. Select the inventory_system database
4. Click Execute to generate the ERD
5. The diagram will display with all tables and relationships
6. Export: File > Export > Export as PNG

---

## Database Features Implemented

### Normalization
- Third Normal Form (3NF) compliance
- No redundant data storage
- Proper functional dependencies
- Atomic column values

### Data Integrity
- Primary keys on all tables ensuring unique row identification
- Foreign keys maintaining referential integrity across tables
- CHECK constraints validating data ranges and values
- NOT NULL constraints preventing incomplete records
- UNIQUE constraints preventing duplicate entries

### Performance Optimization
- Strategic indexes on foreign key columns
- Indexes on date columns for temporal queries
- Indexes on status columns for filtered queries
- Views for frequently accessed aggregated data
- Efficient query structures using appropriate JOIN types

### Advanced SQL Features
- Complex multi-table JOINs (3-4 tables)
- Aggregate functions (SUM, COUNT, AVG, MIN, MAX)
- GROUP BY with HAVING clauses
- Window functions (RANK, DENSE_RANK, ROW_NUMBER, LAG, LEAD)
- Common Table Expressions (CTEs)
- Date and time functions
- Conditional logic with CASE statements
- Transaction management in stored procedures

### Logging and Auditing (Optional Enhancement)
- Comprehensive error tracking and debugging capabilities
- Complete audit trail for all data modifications
- Performance monitoring and query optimization metrics
- Automatic logging via database triggers
- Log maintenance and archival procedures
- Security and compliance support
- Business intelligence and reporting capabilities

The logging system provides:
- **Error Tracking**: Captures all errors with detailed context
- **Audit Trail**: Complete history of data changes
- **Debugging Support**: Detailed information for troubleshooting
- **Compliance**: Support for SOX, GDPR, PCI-DSS requirements

---

## Query Descriptions

### Key Performance Indicators

**Total Revenue Query**
Calculates aggregate revenue from all completed orders (Shipped and Delivered status), including total order count and average order value.

**Top Customers Query**
Identifies the top 10 customers by total spending, displaying customer details alongside their purchase history and total expenditure.

**Best-Selling Products Query**
Ranks products by total quantity sold, limited to the top 5 performers, with total revenue calculations per product.

**Monthly Sales Trend Query**
Aggregates sales data by month using DATE_FORMAT function, showing order counts, total revenue, and average order values for trend analysis.

### Analytical Queries

**Product Rankings by Category**
Demonstrates window functions by ranking products within each category based on sales revenue. Uses RANK(), DENSE_RANK(), and ROW_NUMBER() with PARTITION BY clause to create category-specific rankings.

**Customer Order Frequency**
Analyzes customer purchase patterns using LAG() and LEAD() window functions to show the time elapsed between consecutive orders for each customer, useful for identifying loyal customers and purchase cycles.

### Views

**CustomerSalesSummary**
Pre-aggregated view containing customer purchase metrics including total orders, total spending, average order value, last order date, and order status breakdown by customer.

**ProductInventoryStatus**
Consolidated view joining Products and Inventory tables, calculating total units sold and categorizing stock status (Out of Stock, Low Stock, Medium Stock, High Stock) based on current inventory levels.

### Stored Procedures

**ProcessNewOrder**
Implements complete order processing workflow including:
- Customer validation
- Product existence verification
- Inventory availability checking
- Order record creation
- Order item record creation
- Inventory level updates
- Transaction management (COMMIT on success, ROLLBACK on failure)
- Comprehensive error handling with descriptive messages

---

## Sample Data Statistics

- Customers: 12 records
- Products: 15 records across 3 categories (Electronics, Apparel, Books)
- Orders: 17 records spanning October through December 2024
- Order Items: 29 records
- Order Statuses: Pending (3), Shipped (6), Delivered (8)

---

## Verification

After executing the SQL scripts, verify the database implementation by running these or check the test_queries files:

```sql
-- Verify core tables exist
SHOW TABLES;

-- Verify data loaded
SELECT COUNT(*) AS CustomerCount FROM Customers;
SELECT COUNT(*) AS ProductCount FROM Products;
SELECT COUNT(*) AS OrderCount FROM Orders;

-- Verify views created
SHOW FULL TABLES WHERE TABLE_TYPE LIKE 'VIEW';

-- Verify stored procedures created
SHOW PROCEDURE STATUS WHERE Db = 'inventory_system';

-- Test a sample query
SELECT * FROM CustomerSalesSummary ORDER BY TotalAmountSpent DESC LIMIT 5;

-- If logging system installed, verify logging tables
SELECT COUNT(*) AS LoggingTablesCount 
FROM information_schema.tables 
WHERE table_schema = 'inventory_system' 
AND table_name LIKE '%Log';

-- View system logs (if logging system installed)
SELECT * FROM SystemLog ORDER BY LogTimestamp DESC LIMIT 10;
```

### Testing the Logging System

If you installed the logging system, test its functionality:

```sql
-- Test basic logging
CALL LogSystemEvent('INFO', 'TEST', 'Testing logging functionality', 'Products', 1, NULL);

-- Process an order with full logging
CALL ProcessNewOrderWithLogging(1, 2, 3, @order_id, @message);
SELECT @order_id AS OrderID, @message AS StatusMessage;

-- View the audit trail
SELECT * FROM OrderAuditLog WHERE OrderID = @order_id;

-- Check inventory change log
SELECT * FROM InventoryChangeLog WHERE RelatedOrderID = @order_id;

-- View recent errors (if any)
SELECT * FROM RecentErrors LIMIT 5;

-- Check system health
SELECT * FROM SystemHealthLog WHERE LogDate = CURDATE();

-- View performance metrics
SELECT * FROM QueryPerformanceLog ORDER BY ExecutionTimestamp DESC LIMIT 10;
```

---

## Technical Specifications

**Database Engine:** InnoDB (default for MySQL 8.0+)
**Character Set:** utf8mb4
**Collation:** utf8mb4_general_ci
**SQL Mode:** Default MySQL 8.0 settings
**Transaction Isolation:** REPEATABLE READ (default)

---

## Project Completion Checklist

- Database schema designed and normalized to 3NF
- ERD diagram created showing all tables and relationships
- All five tables created with appropriate data types
- Primary keys defined on all tables
- Foreign keys established for referential integrity
- CHECK constraints implemented for data validation
- Sample data inserted for testing
- Performance indexes created
- Four KPI queries implemented and tested
- Two analytical queries with window functions implemented
- Two views created for performance optimization
- One stored procedure implemented with transaction handling
- All queries documented with clear comments
- Database successfully created and operational

