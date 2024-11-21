source proc.sql

--2.
--Call the stored procedure to fill unit prices in Orderline
CALL proc_FillUnitPrice();

--Call the stored procedure to fill order totals in Orders
CALL proc_FillOrderTotal();

--(Optional) If needed, refresh materialized views after filling unit prices and order totals
CALL proc_RefreshMV();


--3.
CREATE TABLE SalesTax (
    state VARCHAR(2) NOT NULL,
    zip_code DECIMAL(5,0) ZEROFILL PRIMARY KEY,
    tax_region_name VARCHAR(100),
    estimated_combined_rate DECIMAL(5,4) NOT NULL,
    state_rate DECIMAL(5,4) NOT NULL,
    estimated_county_rate DECIMAL(5,4) NOT NULL,
    estimated_city_rate DECIMAL(5,4) NOT NULL,
    estimated_special_rate DECIMAL(5,4) NOT NULL,
    risk_level INT
) ENGINE=InnoDB;

--4.
LOAD DATA LOCAL INFILE '/home/dgomillion/TAXRATES.csv'
INTO TABLE SalesTax
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@State, @ZipCode, @TaxRegionName, @EstimatedCombinedRate, @StateRate, @EstimatedCountyRate, @EstimatedCityRate, @EstimatedSpecialRate, @RiskLevel)
SET
    state = @State,
    zip_code = @ZipCode,
    tax_region_name = @TaxRegionName,
    estimated_combined_rate = @EstimatedCombinedRate,
    state_rate = @StateRate,
    estimated_county_rate = @EstimatedCountyRate,
    estimated_city_rate = @EstimatedCityRate,
    estimated_special_rate = @EstimatedSpecialRate,
    risk_level = @RiskLevel;


--5.
ALTER TABLE `Order`
CHANGE COLUMN orderTotal subtotal DECIMAL(8,2),
ADD COLUMN salesTax DECIMAL(5,2) DEFAULT 0.00,
ADD COLUMN total DECIMAL(8,2) 
GENERATED ALWAYS AS (subtotal + salesTax) VIRTUAL;

--6.
DELIMITER $$

CREATE TRIGGER trg_ProductPriceUpdate
AFTER UPDATE ON Product
FOR EACH ROW
BEGIN
    -- Only insert into PriceHistory if the price has changed
    IF OLD.currentPrice <> NEW.currentPrice THEN
        INSERT INTO PriceHistory (product_id, oldPrice, newPrice, ts)
        VALUES (OLD.id, OLD.currentPrice, NEW.currentPrice, CURRENT_TIMESTAMP());
    END IF;
END $$

DELIMITER ;


--7.

DELIMITER $$

CREATE TRIGGER trg_SetUnitPrice
BEFORE INSERT ON Orderline
FOR EACH ROW
BEGIN
    -- Set the unitPrice in the Orderline to match the currentPrice from the Product table
    SET NEW.unitPrice = (SELECT currentPrice FROM Product WHERE Product. id = NEW.product_id);
END $$

DELIMITER ;



/*DELIMITER $$

CREATE TRIGGER trg_SetUnitPrice
BEFORE INSERT ON Orderline
FOR EACH ROW
BEGIN


    SET NEW.unitPrice = (SELECT currentPrice FROM Product WHERE id = NEW.product_id);


    /*DECLARE product_price DECIMAL(6,2);

    -- Retrieve the current price of the product from the Product table
    SELECT currentPrice INTO product_price
    FROM Product
    WHERE id = NEW.product_id;

    -- Update the unitPrice in Orderline with the retrieved product price
    UPDATE Orderline
    SET unitPrice = product_price;
   -- WHERE order_id = NEW.order_id;
    /*SET NEW.unitPrice = (SELECT currentPrice
    FROM Product WHERE id = NEW.product_id);*/
/*END $$

DELIMITER ;*/

--8.

DELIMITER $$
CREATE TRIGGER trg_InsOrderSubTotal
AFTER INSERT ON Orderline
FOR EACH ROW
BEGIN
    UPDATE POS.Order
    SET subtotal = (SELECT SUM(Orderline.lineTotal) 
        FROM Orderline 
        WHERE Orderline.order_id = POS.Order.id)
    WHERE id = NEW.order_id;
END $$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_UpdOrderSubTotal
AFTER UPDATE ON Orderline
FOR EACH ROW
BEGIN
    UPDATE POS.Order
    SET subtotal = (SELECT SUM(Orderline.lineTotal) 
        FROM Orderline 
        WHERE Orderline.order_id = POS.Order.id)
    WHERE id = NEW.order_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE TRIGGER trg_DelOrderSubTotal
AFTER DELETE ON Orderline
FOR EACH ROW
BEGIN
    UPDATE POS.Order
    SET subtotal = (SELECT SUM(Orderline.lineTotal)
        FROM Orderline
        WHERE Orderline.order_id = POS.Order.id)
    WHERE id = OLD.order_id;
END $$
DELIMITER ;
    

--9.
DELIMITER $$

CREATE TRIGGER trg_SetQtyUnity 
BEFORE INSERT ON Orderline
FOR EACH ROW
BEGIN
    IF NEW.quantity IS NULL THEN
        SET NEW.quantity = 1;
    END IF;
END $$

DELIMITER ;


--Second Condition
DELIMITER $$

CREATE TRIGGER trg_InsProdQty
AFTER INSERT ON Orderline
FOR EACH ROW
BEGIN

        UPDATE Product
        SET availableQuantity = availableQuantity - NEW.quantity
        WHERE id = NEW.product_id;

END $$

DELIMITER ;


DELIMITER $$

CREATE TRIGGER trg_UpdProdQty
AFTER UPDATE ON Orderline
FOR EACH ROW
BEGIN

        UPDATE Product
        SET availableQuantity = availableQuantity + OLD.quantity  - NEW.quantity
        WHERE id = NEW.product_id;

END $$

DELIMITER ;



DELIMITER $$

CREATE TRIGGER trg_DelProdQty
AFTER DELETE  ON Orderline
FOR EACH ROW
BEGIN

        UPDATE Product
        SET availableQuantity = availableQuantity + OLD.quantity
        WHERE id = OLD.product_id;

END $$

DELIMITER ;


--ErrorState

DELIMITER $$
CREATE OR REPLACE TRIGGER trg_QtyExceedsIns 
BEFORE INSERT ON Orderline
FOR EACH ROW
BEGIN

DECLARE stock Integer;
SELECT availableQuantity into stock
FROM Product
where id = NEW.product_id;

IF NEW.quantity > stock THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Quantity requested exceeds.';

END IF;
END $$
DELIMITER ;

DELIMITER $$
CREATE OR REPLACE TRIGGER trg_QtyExceedsUpd
BEFORE UPDATE ON Orderline
FOR EACH ROW
BEGIN

DECLARE stock Integer;
SELECT availableQuantity into stock
FROM Product
where id = NEW.product_id;

IF NEW.quantity > stock THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Quantity requested exceeds.';

    END IF;
END $$
DELIMITER ;



--10
DELIMITER $$

CREATE TRIGGER trg_Ins_Order_Total
AFTER INSERT ON Orderline FOR EACH ROW
BEGIN
   
    DECLARE cust_id int(12);
    DECLARE cust_zipcode decimal(5);
    DECLARE newtaxrate float;

    SELECT DISTINCT customer_id INTO cust_id
    FROM POS.Order o join Orderline ol
    on o.id=ol.order_id
    AND o.id = NEW.order_id;


    SELECT zip INTO cust_zipcode
    FROM Customer
    WHERE id = cust_id;

    SELECT estimated_combined_rate INTO newtaxrate
    FROM SalesTax
    WHERE zip_code = cust_zipcode;

    UPDATE POS.Order
    SET SalesTax = subtotal*newtaxrate
    WHERE id = NEW.order_id;

END $$

DELIMITER ;

--Update trigger
DELIMITER $$

CREATE TRIGGER trg_Upd_Order_Total
AFTER UPDATE ON Orderline FOR EACH ROW
BEGIN

    DECLARE cust_id_upd int(12);
    DECLARE cust_zipcode_upd decimal(5);
    DECLARE newtaxrate_upd float;

    SELECT DISTINCT customer_id INTO cust_id_upd
    FROM POS.Order o join Orderline ol
    on o.id=ol.order_id
    AND o.id = NEW.order_id;


    SELECT zip INTO cust_zipcode_upd
    FROM Customer
    WHERE id = cust_id_upd;

    SELECT estimated_combined_rate INTO newtaxrate_upd
    FROM SalesTax
    WHERE zip_code = cust_zipcode_upd;

    UPDATE POS.Order
    SET SalesTax = subtotal*newtaxrate_upd
    WHERE id = NEW.order_id;

END $$

DELIMITER ;

--Delete trigger
DELIMITER $$

CREATE TRIGGER trg_Del_Order_Total
AFTER DELETE ON Orderline FOR EACH ROW
BEGIN

    DECLARE cust_id_del int(12);
    DECLARE cust_zipcode_del decimal(5);
    DECLARE newtaxrate_del float;

    SELECT DISTINCT customer_id INTO cust_id_del
    FROM POS.Order o join Orderline ol
    on o.id=ol.order_id
    AND o.id = OLD.order_id;


    SELECT zip INTO cust_zipcode_del
    FROM Customer
    WHERE id = cust_id_del;

    SELECT estimated_combined_rate INTO newtaxrate_del
    FROM SalesTax
    WHERE zip_code = cust_zipcode_del;

    UPDATE POS.Order
    SET SalesTax = subtotal*newtaxrate_del
    WHERE id = OLD.order_id;

END $$

DELIMITER ;

/*
--11.
DELIMITER $$
CREATE PROCEDURE mv_CustomerPurchases(IN custidtmp int)
BEGIN
DELETE FROM mv_CustomerPurchases where id = custidtmp;
INSERT INTO mv_CustomerPurchases SELECT
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
WHERE
        Customer.id = custidtmp
GROUP BY
    Customer.id
ORDER BY
    ln, fn;

END $$
DELIMITER ;

--Triggers using procedure written above
DELIMITER $$
CREATE TRIGGER Refresh_MV_Ins 
AFTER INSERT ON Orderline
FOR EACH ROW
BEGIN
    

   DECLARE cust_id_ins int(12);

        SELECT customer_id INTO cust_id_ins
        FROM POS.Order
        WHERE id = NEW.order_id;

    CALL mv_CustomerPurchases(cust_id_ins);

END $$
DELIMITER ;


--Update Trigger


DELIMITER $$
CREATE TRIGGER Refresh_MV_Upd
AFTER UPDATE ON Orderline
FOR EACH ROW
BEGIN


   DECLARE cust_id_upd int(12);

        SELECT customer_id INTO cust_id_upd
        FROM POS.Order
        WHERE id = NEW.order_id;

    CALL mv_CustomerPurchases(cust_id_upd);

END $$
DELIMITER ;

--Delete Trigger
DELIMITER $$
CREATE TRIGGER Refresh_MV_Del
AFTER DELETE ON Orderline
FOR EACH ROW
BEGIN


   DECLARE cust_id_del int(12);

        SELECT customer_id INTO cust_id_del
        FROM POS.Order
        WHERE id = OLD.order_id;

    CALL mv_CustomerPurchases(cust_id_del);

END $$
DELIMITER ;

--PODUCT BUYERS STORED PROCEDURES
DELIMITER $$
CREATE PROCEDURE mv_ProductBuyers(IN prodidtmp INT)
BEGIN
DELETE FROM mv_ProductBuyers where Product.id = prodidtmp;
INSERT INTO mv_ProductBuyers
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
WHERE Product.id = prodidtmp
GROUP BY
    Product.id
ORDER BY
    Product.id;

END $$
DELIMITER ;


--INS TRIGGER

DELIMITER $$
CREATE TRIGGER Refresh_prodbuyins
AFTER INSERT ON Orderline
FOR EACH ROW
BEGIN



    CALL mv_ProductBuyers(NEW.product_id);

END $$
DELIMITER ;



--UPD TRIGGER
DELIMITER $$
CREATE TRIGGER Refresh_prodbuyupd
AFTER UPDATE ON Orderline
FOR EACH ROW
BEGIN



    CALL mv_ProductBuyers(NEW.product_id);

END $$
DELIMITER ;

--DEL TRIGGER
DELIMITER $$
CREATE TRIGGER Refresh_prodbuydel
AFTER DELETE ON Orderline
FOR EACH ROW
BEGIN



    CALL mv_ProductBuyers(OLD.product_id);

END $$
DELIMITER ;
*/

