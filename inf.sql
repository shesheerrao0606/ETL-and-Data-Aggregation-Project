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
