-- =============================
-- SQL DDL SCRIPT: Invetory and Order Management System
-- Database Schema Implementation
-- =============================

-- Drop tables if they exist (for clean re-runs)
DROP TABLE IF EXISTS OrderItems;
DROP TABLE IF EXISTS Orders;
DROP TABLE IF EXISTS Inventory;
DROP TABLE IF EXISTS Products;
DROP TABLE IF EXISTS Customers;


-- TABLE 1: CUSTOMERS
CREATE TABLE Customers (
  CustomerID INT AUTO_INCREMENT PRIMARY KEY,
  FullName VARCHAR(100),
  Email VARCHAR(100),
  Phone VARCHAR(20),
  ShippingAddress VARCHAR(255)
);

-- TABLE 2: PRODUCTS
CREATE TABLE Products (
    ProductID INT PRIMARY KEY AUTO_INCREMENT,
    ProductName VARCHAR(150) NOT NULL,
    Category VARCHAR(50) NOT NULL,
    Price DECIMAL(10, 2) NOT NULL CHECK (Price >= 0)
);

-- TABLE 3: INVENTORY
CREATE TABLE Inventory (
    ProductID INT PRIMARY KEY,
    QuantityOnHand INT NOT NULL DEFAULT 0 CHECK (QuantityOnHand >= 0),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE CASCADE
);

-- TABLE 4: ORDERS
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY AUTO_INCREMENT,
    CustomerID INT NOT NULL,
    OrderDate DATE NOT NULL,
    TotalAmount DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (TotalAmount >= 0),
    OrderStatus VARCHAR(20) NOT NULL DEFAULT 'Pending' 
        CHECK (OrderStatus IN ('Pending', 'Shipped', 'Delivered', 'Cancelled')),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE CASCADE
);

-- TABLE 5: ORDER ITEMS (Bridge Table)
CREATE TABLE OrderItems (
    OrderItemID INT PRIMARY KEY AUTO_INCREMENT,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    PriceAtPurchase DECIMAL(10, 2) NOT NULL CHECK (PriceAtPurchase >= 0),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID) ON DELETE CASCADE,
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE RESTRICT
);

-- INDEXES FOR PERFORMANCE
CREATE INDEX idx_orders_customer ON Orders(CustomerID);
CREATE INDEX idx_orders_date ON Orders(OrderDate);
CREATE INDEX idx_orders_status ON Orders(OrderStatus);
CREATE INDEX idx_orderitems_order ON OrderItems(OrderID);
CREATE INDEX idx_orderitems_product ON OrderItems(ProductID);


-- SAMPLE DATA INSERTION

-- Insert Customers
INSERT INTO Customers (FullName, Email, Phone, ShippingAddress) VALUES
('John Smith', 'john.smith@email.com', '555-0101', '123 Main St, New York, NY 10001'),
('Sarah Johnson', 'sarah.j@email.com', '555-0102', '456 Oak Ave, Los Angeles, CA 90001'),
('Michael Brown', 'mbrown@email.com', '555-0103', '789 Pine Rd, Chicago, IL 60601'),
('Emily Davis', 'emily.davis@email.com', '555-0104', '321 Elm St, Houston, TX 77001'),
('David Wilson', 'dwilson@email.com', '555-0105', '654 Maple Dr, Phoenix, AZ 85001'),
('Jennifer Martinez', 'jmartinez@email.com', '555-0106', '987 Cedar Ln, Philadelphia, PA 19101'),
('Robert Anderson', 'randerson@email.com', '555-0107', '147 Birch Ct, San Antonio, TX 78201'),
('Lisa Taylor', 'ltaylor@email.com', '555-0108', '258 Spruce Way, San Diego, CA 92101'),
('William Thomas', 'wthomas@email.com', '555-0109', '369 Willow Pl, Dallas, TX 75201'),
('Jessica Garcia', 'jgarcia@email.com', '555-0110', '741 Ash Blvd, San Jose, CA 95101'),
('James Rodriguez', 'jrodriguez@email.com', '555-0111', '852 Poplar St, Austin, TX 78701'),
('Mary Hernandez', 'mhernandez@email.com', '555-0112', '963 Walnut Ave, Jacksonville, FL 32099');

-- Insert Products
INSERT INTO Products (ProductName, Category, Price) VALUES
('Laptop Pro 15', 'Electronics', 1299.99),
('Wireless Mouse', 'Electronics', 29.99),
('USB-C Cable', 'Electronics', 12.99),
('Cotton T-Shirt', 'Apparel', 19.99),
('Denim Jeans', 'Apparel', 59.99),
('Running Shoes', 'Apparel', 89.99),
('Python Programming Book', 'Books', 45.00),
('Data Science Handbook', 'Books', 52.00),
('SQL Query Guide', 'Books', 38.00),
('Bluetooth Headphones', 'Electronics', 149.99),
('Smartphone Stand', 'Electronics', 24.99),
('Hoodie Sweatshirt', 'Apparel', 49.99),
('Winter Jacket', 'Apparel', 129.99),
('Machine Learning Book', 'Books', 65.00),
('Smartwatch', 'Electronics', 299.99);

-- Insert Inventory
INSERT INTO Inventory (ProductID, QuantityOnHand) VALUES
(1, 50), (2, 150), (3, 200), (4, 300), (5, 120),
(6, 80), (7, 75), (8, 60), (9, 90), (10, 100),
(11, 180), (12, 140), (13, 70), (14, 55), (15, 45);

-- Insert Orders
INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, OrderStatus) VALUES
(1, '2024-10-15', 1342.97, 'Delivered'),
(2, '2024-10-18', 89.99, 'Shipped'),
(1, '2024-10-22', 149.99, 'Delivered'),
(3, '2024-10-25', 135.00, 'Delivered'),
(4, '2024-11-01', 199.97, 'Shipped'),
(5, '2024-11-05', 79.98, 'Delivered'),
(2, '2024-11-08', 329.98, 'Delivered'),
(6, '2024-11-12', 169.98, 'Shipped'),
(7, '2024-11-15', 1299.99, 'Pending'),
(8, '2024-11-18', 109.98, 'Delivered'),
(3, '2024-11-20', 299.99, 'Shipped'),
(9, '2024-11-22', 89.99, 'Delivered'),
(10, '2024-11-25', 234.97, 'Delivered'),
(4, '2024-11-28', 149.99, 'Shipped'),
(11, '2024-12-01', 179.98, 'Delivered'),
(12, '2024-12-03', 52.00, 'Shipped'),
(1, '2024-12-05', 299.99, 'Pending');

-- Insert Order Items
INSERT INTO OrderItems (OrderID, ProductID, Quantity, PriceAtPurchase) VALUES
-- Order 1 (Customer 1)
(1, 1, 1, 1299.99), (1, 2, 1, 29.99), (1, 3, 1, 12.99),
-- Order 2 (Customer 2)
(2, 6, 1, 89.99),
-- Order 3 (Customer 1)
(3, 10, 1, 149.99),
-- Order 4 (Customer 3)
(4, 7, 1, 45.00), (4, 8, 1, 52.00), (4, 9, 1, 38.00),
-- Order 5 (Customer 4)
(5, 4, 3, 19.99), (5, 5, 2, 59.99),
-- Order 6 (Customer 5)
(6, 2, 1, 29.99), (6, 11, 2, 24.99),
-- Order 7 (Customer 2)
(7, 15, 1, 299.99), (7, 2, 1, 29.99),
-- Order 8 (Customer 6)
(8, 12, 2, 49.99), (8, 13, 1, 129.99),
-- Order 9 (Customer 7)
(9, 1, 1, 1299.99),
-- Order 10 (Customer 8)
(10, 4, 2, 19.99), (10, 12, 1, 49.99), (10, 3, 3, 12.99),
-- Order 11 (Customer 3)
(11, 15, 1, 299.99),
-- Order 12 (Customer 9)
(12, 6, 1, 89.99),
-- Order 13 (Customer 10)
(13, 10, 1, 149.99), (13, 2, 1, 29.99), (13, 11, 2, 24.99),
-- Order 14 (Customer 4)
(14, 10, 1, 149.99),
-- Order 15 (Customer 11)
(15, 13, 1, 129.99), (15, 12, 1, 49.99),
-- Order 16 (Customer 12)
(16, 8, 1, 52.00),
-- Order 17 (Customer 1)
(17, 15, 1, 299.99);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================
SELECT 'Database schema created successfully!' AS Status;
SELECT COUNT(*) AS CustomerCount FROM Customers;
SELECT COUNT(*) AS ProductCount FROM Products;
SELECT COUNT(*) AS OrderCount FROM Orders;
SELECT COUNT(*) AS OrderItemCount FROM OrderItems;