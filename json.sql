-- Dropping database if exixts a database called POS
DROP DATABASE IF EXISTS POS;
CREATE DATABASE POS;
-- Using POS database
USE POS;


-- Creating a Table for Product
CREATE TABLE Product (
        id serial PRIMARY KEY,
        name varchar(128) NOT NULL,
        currentPrice decimal(6,2),
        availableQuantity integer
) ENGINE=InnoDB;

-- Creating a Table for City
CREATE TABLE  City (
        zip decimal(5,0) ZEROFILL  PRIMARY KEY,
        city varchar(32) NOT NULL,
        state varchar(4) NOT NULL
) ENGINE = InnoDB;

-- Creating a Table for Customer

CREATE TABLE Customer (
        id serial PRIMARY KEY,
        firstName varchar(32),
        lastName varchar(30),
        email varchar(128),
        address1 varchar(100),
        address2 varchar(50),
        phone varchar(32),
        birthdate date,
        zip decimal(5,0) ZEROFILL,
        FOREIGN KEY (zip) REFERENCES City(zip)
) ENGINE=InnoDB;

-- Creating a Table for Order
CREATE TABLE `Order`(
        id serial PRIMARY KEY,
        datePlaced date,
        dateShipped date,
        customer_id BIGINT UNSIGNED,
        FOREIGN KEY (customer_id) REFERENCES Customer(id)
) ENGINE = InnoDB;

-- Creating a Table for Orderline
CREATE TABLE  Orderline(
        order_id BIGINT UNSIGNED,
        product_id BIGINT UNSIGNED,
        quantity int,
        PRIMARY KEY (order_id , product_id),
        FOREIGN KEY (order_id) REFERENCES `Order`(id),
        FOREIGN KEY (product_id) REFERENCES Product(id)
) ENGINE = InnoDB;

-- Creating a Table for PriceHistory
CREATE TABLE PriceHistory(
        id serial PRIMARY KEY,
        oldPrice decimal(6,2),
        newPrice decimal(6,2),
        ts timestamp,
        product_id BIGINT UNSIGNED,
        FOREIGN KEY (product_id) REFERENCES Product(id)
) ENGINE = InnoDB;


[dgomillion@ip-172-31-36-15 ~]$ ls
234008689.zip  customers.csv  etl.sql  inf.sql  json.sql  orderlines.csv  orders.csv  proc.sql  products.csv  TAXRATES.csv  trig.sql  views.sql
[dgomillion@ip-172-31-36-15 ~]$ cat json.sql 
source views.sql
--2.
SELECT
    JSON_OBJECT(
        'Customer Name', CONCAT(c.firstName, ' ', c.lastName),
        'Full Address', CONCAT(
            c.address1, '\n',
            IF(c.address2 IS NOT NULL AND c.address2 != '', CONCAT(c.address2, '\n'), ''),
            ci.city, ', ', ci.state, ' ', LPAD(c.zip, 5, '0')  -- Specify the table for Zip
        )
    ) AS CustomerInfo
INTO OUTFILE '/var/lib/mysql/POS/cust.json'  -- Change this path to your home directory
FIELDS TERMINATED BY '\n'
LINES TERMINATED BY '\n'
FROM
    Customer c
JOIN
  City ci ON c.zip = ci.zip;

--3.
SELECT JSON_OBJECT(
    'Product ID', p.id,
    'Price', p.currentPrice,
    'Product Name', p.name,
    'Customers', JSON_ARRAYAGG(
        JSON_OBJECT(
            'CustomerID', c.id,
            'Customer Name', CONCAT(c.firstName, ' ', c.lastName)
        )
    )) AS Customers
INTO OUTFILE '/var/lib/mysql/POS/prod.json'
FIELDS TERMINATED BY '\n'
LINES TERMINATED BY '\n'
FROM
    Product p
LEFT JOIN
    Orderline ol ON p.id = ol.product_id
LEFT JOIN
    `Order` o ON ol.order_id = o.id
LEFT JOIN
     Customer c ON o.customer_id = c.id
GROUP BY
    p.id, p.currentPrice, p.name;

--4.
--4.
SELECT JSON_OBJECT('Order ID', o.id,
'Customer ID', c.id, 'Customer Name', CONCAT(c.firstName, ' ', c.lastName),
'Products', JSON_ARRAYAGG(
        JSON_OBJECT('Product ID', p.id, 'Product Name', p.Name, 'Quantity', ol.quantity )))
INTO OUTFILE '/var/lib/mysql/POS/ord.json'
FROM Product p
RIGHT JOIN Orderline ol
       ON p.id = ol.product_id
RIGHT JOIN `Order` o
       ON ol.order_id = o.id
RIGHT JOIN Customer c
       ON o.customer_id = c.id
GROUP BY c.id, o.id;

--5.
SELECT
    JSON_OBJECT(
        'Customer ID', c.id,
        'Customer Name', CONCAT(c.firstName, ' ', c.lastName),
        'Full Address', CONCAT(
            c.address1, '\n',
            IF(c.address2 IS NOT NULL AND c.address2 != '', CONCAT(c.address2, '\n'), ''),
            City.city, ', ', City.state, ' ', LPAD(c.zip, 5, '0')
        ),
        'Orders', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'Order ID', o.id,
                    'Order Date', o.datePlaced,
                    'Shipping Date', o.dateShipped,
                    'Items', (
                        SELECT JSON_ARRAYAGG(
                                JSON_OBJECT(
                                'Product ID', p.id,
                                'Quantity', ol.quantity,
                                'Product Name', p.name
                            )
                        )
                        FROM Orderline ol
                        JOIN Product p ON ol.product_id = p.id
                        WHERE ol.order_id = o.id
                    )
                )
            )
            FROM `Order` o
            WHERE o.customer_id = c.id
        )
    ) AS CustomerInfo
INTO OUTFILE '/var/lib/mysql/POS/cust2.json'
FIELDS TERMINATED BY '\n'
LINES TERMINATED BY '\n'
FROM
    Customer c
JOIN
    City ON c.zip = City.zip
GROUP BY
    c.id;


--6. What are the most recent orders placed by each customer, including their name and order date?

SELECT
    JSON_OBJECT(
        'Customer ID', c.id,
        'Customer Name', CONCAT(c.firstName, ' ', c.lastName),
        'Recent Orders', JSON_ARRAYAGG(
            JSON_OBJECT(
                'Order ID', o.id,
                'Order Date', o.datePlaced
            )
        )
    ) AS CustomerInfo
INTO OUTFILE '/var/lib/mysql/POS/custom.json'
FIELDS TERMINATED BY '\n'
LINES TERMINATED BY '\n'
FROM
    Customer c
LEFT JOIN
    `Order` o ON c.id = o.customer_id
GROUP BY
    c.id;
