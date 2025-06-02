# Point-of-Sale-System

This repository contains an in-depth academic project where I designed, built, and deployed a fully functional Point of Sale (POS) System using a combination of relational database principles, ETL, stored procedures, triggers, and advanced clustering architectures, later extending it into a NoSQL (MongoDB) environment.

Over 10 milestones, this project walked through the complete data lifecycle — from setting up infrastructure and ingesting messy CSV data to designing normalized relational schemas, optimizing SQL queries, automating logic with procedures and triggers, and finally deploying the system on scalable AWS-hosted clusters (both master-replica and Galera peer-to-peer). It also included exporting JSON from SQL and querying it in MongoDB to simulate hybrid data environments.

# Entity-Relationship Diagram (ERD)  

The Diagram below represents the core relational structure of the Point of Sale (POS) System developed throughout this project. It models the relationships between key entities such as customers, orders, products, and supporting data like cities and price history. At the heart of the schema is the Customer table, which stores personal and contact information. Each customer is linked to a specific city through a ZIP code, promoting normalized and reusable location data. Customers place Orders, and each order is composed of multiple OrderLine entries, connecting products and quantities to that order.

The Product table holds essential information about items available for sale, including their current price and stock quantity. To maintain a historical record of pricing changes, the PriceHistory table logs any updates to a product’s price, including both the old and new prices and a timestamp of when the change occurred. This schema ensures referential integrity through the use of primary and foreign keys and enables complex business logic such as purchase tracking, inventory management, and historical reporting. It served as the foundation for implementing ETL workflows, triggers, stored procedures, and eventually, NoSQL migration using JSON and MongoDB.

<img width="600" alt="image" src="https://github.com/user-attachments/assets/2513103d-113b-4d84-8524-8ca8e7cec39c" />

# Overview 

<img width="600" alt="image" src="https://github.com/user-attachments/assets/a66fedf2-2e6d-42ff-878a-76e67a719508" />

# Detailed overview 

### Milestone 1 : Infrastructure Setup 
This milestone laid the foundation for the entire system. The objective was to set up a fully functional, secure Linux-based database environment using AWS and MariaDB.

- Created an Amazon EC2 instance (Amazon Linux 2023) via AWS Academy
- Configured key-based SSH access for secure remote login
- Installed the latest version of MariaDB using the official repository
- Enabled and started the MariaDB service, ensuring it runs on boot
- Created the `pos` database and granted full privileges to the MariaDB user
- Designed and implemented the relational schema based on the ER diagram
- Wrote all schema creation logic in `structure.sql`, including:
  - Primary and foreign key constraints to enforce data integrity
  - Proper use of `DECIMAL(5) ZEROFILL` to ensure five-digit ZIP codes

This milestone ensured the server was properly secured, database-ready, and prepared for all future development stages in the project.

### Milestone 2 : Extract, Transform, and Load (ETL)

This milestone focused on importing raw, synthetic CSV data into the relational schema and transforming it to fit the normalized database structure. The data included intentional inconsistencies and missing values to simulate real-world scenarios.

- Created an `etl.sql` script to automate the full ETL process
- Began the script with `source` to reset and recreate the database
- Used `LOAD DATA INFILE` to import CSV files into base tables within the `pos` database
- Transformed and cleaned the data post-import, including:
  - Replacing invalid and missing fields (e.g., blank or malformed dates) with `NULL`
  - Aggregating repeated `OrderLine` entries to calculate correct quantities
  - Ensuring ZIP codes display with five digits by using `ZEROFILL`
- Removed or cleaned temporary tables to match the final ER diagram structure
- Verified data consistency and correctness by manually checking customer, order, and product tables after script execution

The ETL milestone demonstrated the importance of preprocessing and cleaning data before it's used in production systems, and reinforced SQL-based data transformation techniques.

### Milestine 3 : Views and Indexes

This milestone focused on improving data accessibility and performance through the use of SQL views, materialized views, and indexes. Views were created to simplify common queries and present data in a more usable format, while indexes were added to optimize read operations.

- Created logical views to simplify data access:
  - `v_CustomerNames`: Listed customers sorted by last and first name
  - `v_Customers`: Presented customer details with full address and renamed fields for clarity
  - `v_ProductBuyers`: Aggregated product buyers into a single comma-separated field per product
  - `v_CustomerPurchases`: Aggregated purchased products per customer, delimited by pipe (`|`) characters
- Developed materialized views:
  - `mv_ProductBuyers` and `mv_CustomerPurchases`, created as real tables for precomputed query results
- Added indexes to improve query performance:
  - `idx_CustomerEmail` on the `Email` field in the `Customer` table
  - `idx_ProductName` on the `Name` field in the `Product` table
- Encapsulated all logic in a dedicated `views.sql` script, which begins by sourcing `etl.sql` to ensure the database is properly initialized

This milestone demonstrated how views and indexes can simplify query logic, support application-specific data presentation, and improve read efficiency in relational databases.

### Milestone 4 : Transactions and Prepared Statements

This milestone explored transactional control and dynamic SQL through prepared statements. It demonstrated how to ensure data consistency, manage rollback scenarios, and protect against SQL injection, all while maintaining safe concurrent access to data.

- Used `START TRANSACTION`, `COMMIT`, and `ROLLBACK` to group SQL statements and ensure atomicity
- Wrote test cases to:
  - Add and remove specific `OrderLine` entries
  - Delete all `OrderLine` rows using both `DELETE` and `TRUNCATE`, observing rollback behavior
- Demonstrated transaction isolation by:
  - Viewing data within an active transaction in the same session
  - Using separate SSH sessions to test visibility of uncommitted changes between sessions
- Answered reflection questions on transactional behavior, commit strategies, and isolation levels
- Created and executed prepared statements to insert data dynamically using parameter placeholders
- Demonstrated the performance benefit of prepared statements when inserting large volumes of data
- Simulated a SQL injection attack using dynamic SQL, then showed how prepared statements mitigate this vulnerability

This milestone emphasized the importance of ACID-compliant operations, safe concurrent data access, and secure query construction in any robust database application.

### Milestone 5 : Stored Procedures

This milestone focused on encapsulating repetitive and business-critical logic into stored procedures, as well as altering the database schema to support calculated and derived values. It introduced automation at the database level for data consistency and reusability.

- Altered existing tables to support calculated and denormalized fields:
  - Added `UnitPrice` to the `OrderLine` table
  - Added a virtual column `LineTotal` to `OrderLine` as `Quantity * UnitPrice`
  - Renamed `OrderTotal` to `OrderSubtotal` in the `Order` table
  - Added a new `OrderTotal` virtual column and a `SalesTax` column to support later calculations
  - Removed the `Phone` field from the `Customer` table
- Created stored procedures and encapsulated logic in `proc.sql`:
  - `proc_FillUnitPrice`: Populated null `UnitPrice` values in `OrderLine` using the current price from `Product`
  - `proc_FillOrderTotal`: Aggregated `LineTotal` values to populate `OrderSubtotal` where null
  - `proc_RefreshMV`: Refreshed both materialized views (`mv_ProductBuyers` and `mv_CustomerPurchases`) in a transaction-safe way
- Procedures were written to be reusable and tested independently after the database was restored

This milestone reinforced the benefits of encapsulating logic in stored procedures, especially for maintaining data quality and enabling modular, repeatable operations at the database level.

### Milestone 6 : Database Triggers

This milestone introduced database triggers to automate real-time updates and enforce data consistency without relying on application-side logic. It involved writing multiple `BEFORE` and `AFTER` triggers to respond to insert, update, and delete operations across several tables.

- Created a new `SalesTax` table to store tax rates by ZIP code, using appropriate precision for fractional percentages
- Altered the `Order` and `PriceHistory` tables:
  - Made `ChangeID` in `PriceHistory` auto-increment and defaulted its timestamp to `NOW()`
  - Renamed `OrderTotal` to `OrderSubtotal`
  - Added a new `SalesTax` column with a default of `0.00`
  - Introduced a virtual column `OrderTotal` computed as `OrderSubtotal + SalesTax`
- Wrote triggers to automate business rules:
  - Inserted a new record into `PriceHistory` only when a product’s price changes
  - Set default `Quantity = 1` in `OrderLine` if not provided
  - Pulled `UnitPrice` from the current price in `Product` during `OrderLine` insert
  - Updated `QtyOnHand` in `Product` when `OrderLine` records were inserted, updated, or deleted
  - Prevented `OrderLine` inserts if the quantity exceeded available inventory
  - Recalculated `OrderSubtotal` and `SalesTax` after order changes using proper rounding rules
- Updated materialized views incrementally by calling helper procedures from within triggers rather than refreshing full views

This milestone ensured that the system could enforce core business logic at the database level, reducing the risk of inconsistencies and improving data integrity in transactional operations.

### Milestone 7 : Master-Replica Clustering

This milestone focused on setting up a traditional master-replica (primary-secondary) MariaDB clustering model to support horizontal scalability for read-heavy workloads. The goal was to replicate the production database across multiple nodes to offload read queries and improve performance.

- Launched three new EC2 instances on AWS and configured them as database servers
- Designated one instance as the **primary (writer)** and two as **replicas (read-only)**
- Configured firewall settings to open port `3306` for internal communication between nodes
- Created a dedicated replication user on the primary instance with appropriate privileges
- Updated MariaDB configuration files (`my.cnf`) on all instances:
  - Assigned unique `server_id` values
  - Enabled `read_only` mode on the replicas
  - Used private IP addresses to establish secure, persistent replication channels
- Initialized the `pos` database on the primary node by executing `views.sql`
- Verified replication by:
  - Inserting and deleting orders on the primary and observing propagation to replicas
  - Confirming that write operations were blocked on replicas due to `read_only` mode
  - Measuring replication delay, which was typically under 1–2 seconds after changes

This milestone demonstrated how to scale a database system for read performance and high availability using MariaDB’s native replication capabilities, simulating real-world production deployment environments.

### Milestone 8 : Peer-to-Peer Clustering (Galera)

This milestone focused on setting up a peer-to-peer clustering model using **MariaDB with Galera Cluster**, allowing for fully-synchronous multi-master replication. Unlike traditional master-replica setups, this architecture enables write operations on any node and ensures high availability and consistency across all nodes.

- Launched three new EC2 instances on AWS, labeled Node A, Node B, and Node C
- Configured system startup/shutdown order to maintain cluster health (A → B → C on startup; C → B → A on shutdown)
- Installed and configured **MariaDB with Galera support** on all three nodes
- Updated `server.cnf` to include:
  - Unique `server_id` values
  - `wsrep_cluster_address` with all private IPs for cluster connectivity
  - `wsrep_node_address`, `wsrep_node_name`, and required Galera settings
- Enabled `wsrep_sst_method=rsync` for state snapshot transfer and initial syncing
- Created the `dgomillion` Linux and MariaDB users on all nodes for uniform access
- Copied and ran `views.sql` on any node to initialize the database and verify replication
- Performed cross-node tests to confirm:
  - Writes from any node were instantly reflected on all others
  - Schema and data consistency was maintained cluster-wide
  - Orders inserted or deleted from one node were immediately visible on the rest
  - The system supported full fault tolerance without requiring a dedicated primary node

This milestone demonstrated how to implement a production-grade, fault-tolerant, and scalable database system using synchronous multi-master replication, ideal for high-availability environments and distributed applications.

### Milestone 9 : JSON Export for NoSQL

This milestone focused on preparing and exporting relational data from the MariaDB database into denormalized JSON documents suitable for import into a NoSQL system, specifically MongoDB. The process simulated how modern applications transition from normalized SQL schemas to document-based models for flexibility and performance.

- Created a `json.sql` script that began by sourcing `trig.sql` to ensure the database was fully prepared with triggers and up-to-date data
- Used MariaDB’s `JSON_OBJECT` and `JSON_ARRAYAGG` functions to generate properly structured JSON output
- Exported four distinct JSON files to support different NoSQL use cases:
  - `cust1.json`: Contained customer information with a combined full name and multi-line formatted address (excluded `Address2` when null)
  - `prod.json`: Represented products and an array of unique customers who purchased each product
  - `ord.json`: Contained orders with embedded buyer and product objects, including quantities
  - `cust2.json`: Combined `cust1` details with an embedded array of each customer's order history and associated items
- Used `INTO OUTFILE` statements to save the JSON objects directly on the MariaDB server (typically in `/var/lib/mysql/pos`)
- Ensured the output followed a line-separated JSON format (one object per line, no commas), compatible with `mongoimport`
- Validated structure using JSON linters and pretty-printers to ensure syntax correctness and document integrity

This milestone demonstrated how to denormalize relational data and prepare it for document-oriented storage, simulating real-world NoSQL export pipelines and hybrid data architecture workflows.

### Milesstone 10 :  MongoDB Integration

This final milestone focused on transitioning the denormalized JSON documents generated in the previous phase into a NoSQL environment using MongoDB. It involved importing JSON files, running analytical queries, and comparing the experience and structure of NoSQL against traditional relational systems.

- Deployed a new EC2 instance and installed **MongoDB** on Amazon Linux 2023 using custom repo configurations
- Successfully imported all four JSON documents using the `mongoimport` command:
  - `cust1.json` → `Customers` collection
  - `cust2.json` → `CustomerOrders` collection
  - `prod.json` → `Products` collection
  - `ord.json` → `Orders` collection
- Verified imports by checking document counts and sampling documents in the MongoDB shell (`mongosh`)
- Wrote and executed several queries to answer practical business questions:
  - Identified all customers who live in Texas using embedded address data
  - Determined the best customer by aggregating total order amounts
  - Found the most frequently purchased product based on customer activity
  - Flagged products with low or no sales as potential drop candidates
  - Retrieved a list of customers for a specific product in case of a recall
  - Analyzed potential fraudulent orders based on unusual quantities or totals
- Reflected on the MongoDB development experience by answering:
  - Differences between SQL and MongoDB querying
  - The impact of denormalization on document structure and data retrieval
  - How business logic shifts from SQL joins to aggregation pipelines and embedded arrays

This milestone demonstrated how to migrate data from a relational system into a NoSQL environment, highlighting the differences in modeling, querying, and business-layer responsibility between SQL and document-based systems like MongoDB.

## Final Notes

This project was developed as part of a university-level database systems course, designed to simulate real-world enterprise database scenarios using open-source tools and cloud infrastructure. It covered the full lifecycle of building a production-ready data system — from schema design and ETL to automation, clustering, and NoSQL integration.

Due to academic integrity policies, the source code and raw data files are not publicly shared. However, this repository documents the design decisions, architecture, and technologies used across each milestone. It serves as a reflection of the practical experience gained in managing complex database systems using both SQL and NoSQL paradigms.

📫 **Want to learn more or collaborate on database-heavy projects?** Feel free to reach out.

# Author:

```bash
Author: Sai Kiran Reddy Dyavadi
Role  : Data Scientist
Email : dyavadi324@gmail.com
```
