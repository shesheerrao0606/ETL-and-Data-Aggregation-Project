source views.sql
--2.
-- Adding unitPrice:
ALTER TABLE Orderline
ADD COLUMN unitPrice DECIMAL(6,2);

--Adding lineTotal:
ALTER TABLE Orderline
ADD COLUMN lineTotal DECIMAL(8,2) 
GENERATED ALWAYS AS (quantity * unitPrice) VIRTUAL;

--Adding orderTotal:
ALTER TABLE `Order`
ADD COLUMN orderTotal DECIMAL(8,2);
-- Removing the phone column:
ALTER TABLE Customer
DROP COLUMN phone;
-- Updating ts column in the PriceHistory table
ALTER TABLE PriceHistory
MODIFY COLUMN ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP() 
ON UPDATE CURRENT_TIMESTAMP();

--3.
DELIMITER $$
CREATE PROCEDURE proc_FillUnitPrice()
BEGIN
    UPDATE Orderline ol
    JOIN Product p ON ol.product_id = p.id
    SET ol.unitPrice = p.currentPrice
    WHERE ol.unitPrice IS NULL;
END $$

DELIMITER ;

--4.

DELIMITER $$

CREATE PROCEDURE proc_FillOrderTotal()
BEGIN
    UPDATE `Order` o
    JOIN (
        SELECT order_id, SUM(lineTotal) AS total
        FROM Orderline
        GROUP BY order_id
    ) ol ON o.id = ol.order_id
    SET o.orderTotal = ol.total
    WHERE o.orderTotal IS NULL;
END $$

DELIMITER ;
--5.
DELIMITER $$

CREATE PROCEDURE proc_RefreshMV()
BEGIN
    -- Start transaction for safety
    START TRANSACTION;

    DELETE FROM mv_ProductBuyers;
    INSERT INTO mv_ProductBuyers (productID, productName, customers)
    SELECT p.id, p.name, GROUP_CONCAT(DISTINCT CONCAT(c.id, ' ', c.firstName, ' ', c.lastName) ORDER BY c.id SEPARATOR ',')
    FROM Product p
    LEFT JOIN Orderline ol ON p.id = ol.product_id
    LEFT JOIN `Order` o ON ol.order_id = o.id
    LEFT JOIN Customer c ON o.customer_id = c.id
    GROUP BY p.id;

    DELETE FROM mv_CustomerPurchases;
    INSERT INTO mv_CustomerPurchases
    SELECT * FROM v_CustomerPurchases;
    
    COMMIT;
END $$

DELIMITER ;

--6.
DELIMITER $$

CREATE PROCEDURE proc_AddItem(
    IN p_orderID INT, 
    IN p_productID INT, 
    IN p_quantity INT
)
BEGIN
    
    DECLARE v_unitPrice DECIMAL(6,2);
    DECLARE v_lineTotal DECIMAL(8,2);

    -- Retrieve currentPrice from Product
    SELECT currentPrice INTO v_unitPrice 
    FROM Product 
    WHERE id = p_productID;

    SET v_lineTotal = v_unitPrice * p_quantity;

    INSERT INTO Orderline (order_id, product_id, quantity, unitPrice) 
    VALUES (p_orderID, p_productID, p_quantity, v_unitPrice);

    UPDATE Product
    SET availableQuantity = availableQuantity - p_quantity
    WHERE id = p_productID;

    UPDATE `Order` o
    SET o.orderTotal =o.orderTotal + v_lineTotal
       -- SELECT (p_quantity * unitPrice) 
       -- FROM Orderline ol 
       -- WHERE ol.order_id = p_orderID
   -- )
    WHERE o.id = p_orderID;

END $$

DELIMITER ;

--7.
DELIMITER $$

CREATE PROCEDURE proc_SalesReport(
    IN p_startDate DATE,
    IN p_endDate DATE,
    IN p_productID INT
)
BEGIN
    SELECT 
        ol.product_id AS "Product ID",
        SUM(ol.quantity) AS "Quantity Sold",
        SUM(ol.lineTotal) AS "Total Sales Amount"
    FROM 
        Orderline ol
    JOIN `Order` o ON ol.order_id = o.id
    WHERE 
        o.datePlaced BETWEEN p_startDate AND p_endDate
        AND ol.product_id = p_productID
    GROUP BY ol.product_id;
END $$

DELIMITER ;


--8.
DELIMITER $$

CREATE PROCEDURE proc_UpdatePrice(
    IN p_productID INT, 
    IN p_newPrice DECIMAL(6,2)
)
BEGIN
    DECLARE v_oldPrice DECIMAL(6,2);

    SELECT currentPrice INTO v_oldPrice
    FROM Product 
    WHERE id = p_productID;

    UPDATE Product
    SET currentPrice = p_newPrice
    WHERE id = p_productID;

    INSERT INTO PriceHistory (product_id, oldPrice, newPrice, ts)
    VALUES (p_productID, v_oldPrice, p_newPrice, CURRENT_TIMESTAMP());

END $$

DELIMITER ;
