--Source command for inf.sql
source inf.sql;

--Creating the temporary tables for data processing

-- Creating temporary Customer table
CREATE TABLE CustomerTemp(
    CustomerID INT PRIMARY KEY,
    FirstName VARCHAR(32),
    LastName VARCHAR(32),
    City VARCHAR(32),
    State VARCHAR(128),
    Zip DECIMAL(5,0) ZEROFILL,
    Address1 VARCHAR(128),
    Address2 VARCHAR(128),
    Email VARCHAR(128),
    Birthdate DATE
) ENGINE=InnoDB;

-- Creating temporary Product table
CREATE TABLE TempProduct (
    ID INT,
    Name VARCHAR(128),
    Price VARCHAR(20),
    `Quantity on Hand` INT
);

-- Creating temporary Orders table
CREATE TABLE TempOrders (
    OID INT,
    CID INT,
    Ordered DATETIME,
    Shipped VARCHAR(20)
);

-- Creating temporary OrderLine table
CREATE TABLE TempOrderLine (
    OID INT,
    PID INT
);

-- Loading the data into temporary tables
-- Ensuring that the data is loaded in the correct order to maintain FOREIGN KEY RELATIONSHIPS

-- Loading data into CustomerTemp
LOAD DATA LOCAL INFILE '/home/dgomillion/customers.csv'
INTO TABLE CustomerTemp
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(CustomerID, FirstName, LastName, City, State, Zip, Address1, Address2, Email, @Birthdate)
SET Birthdate = STR_TO_DATE(@Birthdate, "%m/%d/%Y");

-- Updating the CustomerTemp table to handle missing data
UPDATE CustomerTemp
SET Address2 = NULLIF(Address2, '');

UPDATE CustomerTemp
SET Birthdate = NULLIF(Birthdate, '0000-00-00');

-- Adding Phone column to CustomerTemp (since phone numbers are missing, everything will be NULL)
ALTER TABLE CustomerTemp
ADD Phone VARCHAR(32) NULL;

-- Inserting data into City table
INSERT INTO City (zip, city, state)
SELECT DISTINCT Zip, City, State
FROM CustomerTemp;

-- Inserting data from CustomerTemp into the permanent Customer table
INSERT INTO Customer (id, firstName, lastName, email, address1, address2, phone, birthdate, zip)
SELECT
    CustomerID,
    FirstName,
    LastName,
    Email,
    Address1,
    Address2,
    Phone,  -- All phones are NULL
    Birthdate,
    Zip
FROM CustomerTemp;

-- Loading data into TempProduct
LOAD DATA LOCAL INFILE '/home/dgomillion/products.csv'
INTO TABLE TempProduct
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Loading data into TempOrders
LOAD DATA LOCAL INFILE '/home/dgomillion/orders.csv'
INTO TABLE TempOrders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Loading data into TempOrderLine
LOAD DATA LOCAL INFILE '/home/dgomillion/orderlines.csv'
INTO TABLE TempOrderLine
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Transfer of data from TempProduct to the permanent Product table
INSERT INTO Product (id, name, currentPrice, availableQuantity)
SELECT
    ID,
    Name,
    CAST(REPLACE(REPLACE(Price, '$', ''), ',', '') AS DECIMAL(6,2)),  -- Remove '$' and ',' from price, cast to decimal
    `Quantity on Hand`
FROM TempProduct;

--Transfer of datafrom TempOrders to the permanent `Order` table
INSERT INTO `Order` (id, datePlaced, dateShipped, customer_id)
SELECT
    OID,
    Ordered,
    CASE WHEN Shipped = 'Cancelled' THEN NULL ELSE Shipped END,  -- Set 'Cancelled' shipped dates to NULL
    CID
FROM TempOrders;

-- Transfe ofdata from TempOrderLine to the permanent OrderLine table
INSERT INTO Orderline (order_id, product_id, quantity)
SELECT
    OID,
    PID,
    COUNT(*)  -- Aggregate quantity using GROUP BY
FROM TempOrderLine
GROUP BY OID, PID;





--SELECT * FROM Customer LIMIT 10;

-- Show first 10 rows from Product table
--SELECT * FROM Product LIMIT 10;

-- Show first 10 rows from Order table
--SELECT * FROM `Order` LIMIT 10;

-- Show first 10 rows from OrderLine table
--SELECT * FROM Orderline LIMIT 10;


-- After processing, drop the temporary tables



DROP TABLE CustomerTemp;
DROP TABLE TempProduct;
DROP TABLE TempOrders;
DROP TABLE TempOrderLine;