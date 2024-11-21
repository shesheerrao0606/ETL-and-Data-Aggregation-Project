source etl.sql
--1. Creating View for v_customers
CREATE VIEW v_customers AS
SELECT
    lastName AS `Last Name`,
    firstName AS `First Name`
FROM
    Customer
ORDER BY
    lastName ASC,
    firstName ASC;

--2. Creating view v_customers2
CREATE VIEW v_customers2 AS
SELECT
    Customer.id AS customer_number,
    Customer.firstName AS first_name,
    Customer.lastName AS last_name,
    CONCAT(Customer.address1, IF(Customer.address2 IS NOT NULL AND Customer.address2 != '', CONCAT(', ', Customer.address2), '')) AS addr1,
    CONCAT(City.city, ', ', City.state, '   ', LPAD(Customer.zip, 5, '0')) AS addr2
FROM
    Customer
JOIN
    City ON Customer.zip = City.zip
ORDER BY
    Customer.zip;

--3. Creating View v_ProductBuyers
CREATE VIEW v_ProductBuyers AS
SELECT
    Product.id AS productID,
    Product.name AS productName,
    GROUP_CONCAT(
        DISTINCT CONCAT(
            Customer.id, ' ', Customer.firstName, ' ', Customer.lastName
        ) ORDER BY Customer.id SEPARATOR ','
    ) AS customers
FROM
    Product
LEFT JOIN
    Orderline ON Product.id = Orderline.product_id
LEFT JOIN
    `Order` ON Orderline.order_id = `Order`.id
LEFT JOIN
    Customer ON `Order`.customer_id = Customer.id
GROUP BY
    Product.id
ORDER BY
    Product.id;


--4.Creating View v_CustomerPurchases

CREATE VIEW v_CustomerPurchases AS
SELECT
    Customer.id AS `customer number`,
    Customer.firstName AS fn,
    Customer.lastName AS ln,
    GROUP_CONCAT(
        DISTINCT CONCAT(
            Product.id, ' ', Product.name
        ) ORDER BY Product.id SEPARATOR '|'
    ) AS products
FROM
    Customer
LEFT JOIN
    `Order` ON Customer.id = `Order`.customer_id
LEFT JOIN
    Orderline ON `Order`.id = Orderline.order_id
LEFT JOIN
    Product ON Orderline.product_id = Product.id
GROUP BY
    Customer.id
ORDER BY
    ln, fn;
--5.
--MV for ProductBuyers
--CREATE TABLE mv_ProductBuyers AS
/*SELECT
    productID,
    productName,
    customers
FROM
    v_ProductBuyers;
--MV for CustomerPurchases
CREATE TABLE mv_CustomerPurchases AS
SELECT
    `customer number`,
    fn,
    ln,
    products
FROM
    v_CustomerPurchases;

*/
--5.Creating the Materialized VIEWS
CREATE OR REPLACE TABLE  mv_ProductBuyers
AS SELECT * FROM v_ProductBuyers;

CREATE OR REPLACE TABLE  mv_CustomerPurchases 
AS SELECT * FROM v_CustomerPurchases;



--6.Indexes 1
CREATE INDEX idx_CustomerEmail
ON Customer (email);

--7.Indexes 2
CREATE INDEX idx_ProductName
ON Product (name);
