# ETL and Data Aggregation Project

This project demonstrates an ETL (Extract, Transform, Load) pipeline deployed on an AWS EC2 instance. The pipeline processes raw customer, order, and product data stored in MariaDB, performs data cleansing, and generates insightful JSON-based nested aggregates. These aggregates are then integrated into MongoDB for scalable storage and advanced querying.

## Features

- **ETL Pipeline**: Processes and transforms raw data across multiple tables into meaningful insights.
- **AWS EC2 Deployment**: The entire pipeline is hosted on a cloud instance to ensure scalability and reliability.
- **MariaDB**: Used for relational data storage, schema design, and generating complex nested JSON aggregates.
- **MongoDB Integration**: Provides scalable and flexible storage for querying aggregated data.
- **JSON Aggregates**: Generates nested JSON documents for:
  - Customer order history with order details and purchased items.
  - Product purchase details, including buyers and order quantities.
  
## Schema Overview

### Tables
1. **Product**
    - `id`: Product ID
    - `name`: Product Name
    - `currentPrice`: Current Price
    - `availableQuantity`: Quantity in Stock

2. **City**
    - `zip`: ZIP Code
    - `city`: City Name
    - `state`: State Name

3. **Customer**
    - `id`: Customer ID
    - `firstName`: First Name
    - `lastName`: Last Name
    - `email`: Email Address
    - `address1`: Primary Address
    - `address2`: Secondary Address (optional)
    - `phone`: Phone Number
    - `birthdate`: Birthdate
    - `zip`: ZIP Code (linked to City)

4. **Order**
    - `id`: Order ID
    - `datePlaced`: Date the order was placed
    - `dateShipped`: Shipping Date
    - `customer_id`: Linked Customer ID

5. **Orderline**
    - `order_id`: Linked Order ID
    - `product_id`: Linked Product ID
    - `quantity`: Quantity ordered
  
<img width="749" alt="erd" src="https://github.com/user-attachments/assets/d61ee7ad-dbc7-4f13-a0e6-8f7271a6f5eb">


### Aggregates
1. **Customer Order History**: Combines customer information with an array of orders and order details.
2. **Product Purchase Details**: Lists products with an array of customers who purchased them.

## Tools and Technologies

- **AWS EC2**: Hosted the project for cloud scalability.
- **MariaDB**: Managed relational data and performed ETL transformations.
- **MongoDB**: Used for storing and querying aggregated JSON documents.
- **SQL**: Wrote complex queries for data extraction and aggregation.
- **Linux**: Configured the server environment and automated tasks.

## File Structure

```plaintext
├── scripts/
│   ├── create_schema.sql      # SQL script for creating tables
│   ├── etl_script.sql         # ETL script for data processing
│   ├── generate_aggregates.sql  # Queries for JSON aggregates
├── json/
│   ├── cust.json              # Customer JSON aggregates
│   ├── prod.json              # Product JSON aggregates
│   ├── custom.json            # Additional custom JSON aggregates
├── README.md                  # Project documentation
```
## Example Queries
## MariaDB
1. List all customers and their associated cities:
sql

SELECT CONCAT(c.firstName, ' ', c.lastName) AS CustomerName, ci.city, ci.state
FROM Customer c
JOIN City ci ON c.zip = ci.zip;

## 2. Get all orders with total price and shipping date:
sql

SELECT o.id AS OrderID, o.datePlaced, o.dateShipped, SUM(ol.quantity * p.currentPrice) AS OrderTotal
FROM `Order` o
JOIN Orderline ol ON o.id = ol.order_id
JOIN Product p ON ol.product_id = p.id
GROUP BY o.id;

## 3. Get products purchased by a specific customer (e.g., customer ID = 1):
sql

SELECT p.name AS ProductName, ol.quantity
FROM Orderline ol
JOIN Product p ON ol.product_id = p.id
JOIN `Order` o ON ol.order_id = o.id
WHERE o.customer_id = 1;

MongoDB
1. Find all orders placed by a specific customer (e.g., Customer ID = 1):

db.customers.find({ "Customer ID": 1 }, { "Orders": 1 });

2. Get all products purchased by customers in a specific city (e.g., "Houston"):

db.customers.find({ "Full Address": /Houston/ }, { "Orders.Items.Product Name": 1 });

## 3. List all products with their buyers:

db.products.find({}, { "Product Name": 1, "Buyers": 1 });

## How to Run
Launch an AWS EC2 instance with the required Linux distribution.
Install MariaDB and MongoDB on the instance.
Clone this repository and upload the scripts to the instance.
Run the SQL scripts in order:
create_schema.sql to set up the database schema.
etl_script.sql to load and clean data.
generate_aggregates.sql to generate JSON-based aggregates.
Store the generated JSON files in MongoDB for further analysis.
