# ShopFlow Analytics: dbt + Databricks
End-to-end sales analytics on orders and customers using dbt and Databricks: staging, intermediate and mart layers, with tests, documentation and SQL analysis on top.

## 1. Project overview

ShopFlow is a sample e-commerce dataset (customers, products, orders and order items). This project turns the raw CSV files into clean, tested, analysis-ready tables using the layered approach recommended by dbt, then answers business questions about sales, products and customers.

Business questions answered

How do sales and order volumes change month by month?
Which products and categories generate the most revenue?
Which countries and customers contribute the most?
How many customers are repeat buyers?
What share of orders is delivered, shipped or still processing?
2. Tech stack
Tool	Purpose
dbt (dbt-databricks adapter)	Transformations, testing, documentation, lineage
Databricks (SQL Warehouse / Unity Catalog)	Compute and storage
SQL	Modelling and analysis
Git / GitHub	Version control
3. Source data

Four raw CSV files are loaded as dbt seeds (seeds/ folder).

File	Grain	Primary key	Rows
raw_customers.csv	one row per customer	customer_id	8,010
raw_products.csv	one row per product	product_id	7,010
raw_orders.csv	one row per order	order_id	12,020
raw_order_items.csv	one row per product line in an order	order_item_id	5,030

Relationships

raw_orders.customer_id → raw_customers.customer_id
raw_order_items.order_id → raw_orders.order_id
raw_order_items.product_id → raw_products.product_id

The first 10 / 10 / 20 / 30 rows in each file are the original sample data. The remaining rows were generated to match the same schema, keys and patterns. Order dates run from 2024-06-01 to 2024-12-31.

Known raw data quirks (handled in staging)

Inconsistent casing in some names and emails (for example johnson, IVY.t@email.com).
Some unit_price values differ from the product list price (discounts or price changes).
Only part of the orders have matching rows in raw_order_items, so some orders have no item detail.
At least one original order total does not equal the sum of its items (ord_007).
4. Architecture
seeds (raw CSV)
      │
      ▼
 STAGING          one model per source table: rename, cast, clean
 stg_customers, stg_products, stg_orders, stg_order_items
      │
      ▼
 INTERMEDIATE     joins and business logic, not exposed to end users
 int_order_items_enriched, int_orders_summary, int_customer_orders
      │
      ▼
 MARTS            analysis-ready dimensions and facts
 dim_customers, dim_products, fct_orders, fct_order_items
      │
      ▼
 ANALYSIS         SQL queries / dashboards
5. Project structure
shopflow_analytics/
├── dbt_project.yml
├── packages.yml
├── seeds/
│   ├── raw_customers.csv
│   ├── raw_products.csv
│   ├── raw_orders.csv
│   └── raw_order_items.csv
├── models/
│   ├── staging/
│   │   ├── stg_customers.sql
│   │   ├── stg_products.sql
│   │   ├── stg_orders.sql
│   │   ├── stg_order_items.sql
│   │   └── _staging.yml
│   ├── intermediate/
│   │   ├── int_order_items_enriched.sql
│   │   ├── int_orders_summary.sql
│   │   ├── int_customer_orders.sql
│   │   └── _intermediate.yml
│   └── marts/
│       ├── dim_customers.sql
│       ├── dim_products.sql
│       ├── fct_orders.sql
│       ├── fct_order_items.sql
│       └── _marts.yml
├── analyses/
│   ├── monthly_sales.sql
│   ├── top_products.sql
│   ├── sales_by_country.sql
│   ├── repeat_customers.sql
│   └── order_status_mix.sql
└── tests/
    └── assert_order_total_matches_items.sql
6. Model layers
6.1 Staging (models/staging)

Light-touch cleaning only, one model per source, materialised as views.

Model	What it does
stg_customers	Standardises names (initcap), lower-cases email, casts created_at to timestamp
stg_products	Trims text, casts price to decimal
stg_orders	Casts order_date to date, standardises status to lower case
stg_order_items	Casts quantity and price, adds line_total = quantity * unit_price
6.2 Intermediate (models/intermediate)

Joins and calculations reused by several marts.

Model	What it does
int_order_items_enriched	Order items joined to orders and products (date, status, category, customer)
int_orders_summary	One row per order with item count, units and calculated item total
int_customer_orders	One row per customer with first order date, last order date, order count and total spend
6.3 Marts (models/marts)

Business-facing tables, materialised as tables (schema: gold).

Model	Type	Description
dim_customers	Dimension	Customer attributes plus lifetime metrics (orders, spend, first and last order)
dim_products	Dimension	Product name, category and list price
fct_orders	Fact	One row per order with status, total and item count
fct_order_items	Fact	One row per order line with product, quantity, price and line total
7. Data quality tests

Defined in the _*.yml files and in tests/.

unique and not_null on every primary key.
relationships between orders and customers, items and orders, items and products.
accepted_values for status (delivered, shipped, processing) and country (US, UK, CA, DE).
Custom test: order total_amount should match the sum of its item line totals. Orders with no items are excluded, and known source mismatches are set to warn severity.
bash
dbt test
8. How to run

Prerequisites: Python 3.9+, a Databricks workspace with a SQL Warehouse, and a personal access token.

bash
# 1. Clone the repo
git clone https://github.com/<your-username>/shopflow-dbt-databricks-analytics.git
cd shopflow-dbt-databricks-analytics

# 2. Install dbt with the Databricks adapter
pip install dbt-databricks

# 3. Configure your connection (see below), then check it
dbt debug

# 4. Install packages, load seeds, build and test
dbt deps
dbt seed
dbt run
dbt test

# 5. Generate and view documentation and lineage
dbt docs generate
dbt docs serve

~/.dbt/profiles.yml (keep this file out of Git; never commit tokens):

yaml
shopflow_analytics:
  target: dev
  outputs:
    dev:
      type: databricks
      host: "{{ env_var('DATABRICKS_HOST') }}"
      http_path: "{{ env_var('DATABRICKS_HTTP_PATH') }}"
      token: "{{ env_var('DATABRICKS_TOKEN') }}"
      catalog: main
      schema: gold
      threads: 4
9. Analysis

Queries live in analyses/ and run in the Databricks SQL editor. They are written in Databricks SQL (for example, date_format for month names).

Monthly sales

sql
select
    year(order_date)                    as order_year,
    month(order_date)                   as month_num,
    date_format(order_date, 'MMMM')     as month_name,
    count(distinct order_id)            as orders,
    sum(line_total)                     as revenue
from gold.fct_order_items
group by year(order_date), month(order_date), date_format(order_date, 'MMMM')
order by order_year, month_num;

Top 10 products by revenue

sql
select
    p.product_name,
    p.category,
    sum(f.quantity)     as units_sold,
    sum(f.line_total)   as revenue
from gold.fct_order_items f
join gold.dim_products p on f.product_id = p.product_id
group by p.product_name, p.category
order by revenue desc
limit 10;

Revenue by country

sql
select
    c.country,
    count(distinct o.order_id)  as orders,
    sum(o.total_amount)         as revenue
from gold.fct_orders o
join gold.dim_customers c on o.customer_id = c.customer_id
group by c.country
order by revenue desc;

Repeat vs one-time customers

sql
select
    case when total_orders > 1 then 'Repeat' else 'One-time' end as customer_type,
    count(*) as customers
from gold.dim_customers
where total_orders > 0
group by 1;

Order status mix

sql
select
    status,
    count(*) as orders,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as pct_of_orders
from gold.fct_orders
group by status
order by orders desc;
10. Key findings

Add your own results here after running the queries, for example:

Revenue peaked in [month] at [value].
[Category] generated [x%] of revenue.
[x%] of customers placed more than one order.
[Country] is the largest market by revenue.

Add screenshots below:

Lineage graph	Monthly sales chart
docs/lineage.png	docs/monthly_sales.png
11. Notes and limitations
Data is sample data and partly synthetic; results illustrate the method, not a real business.
Only a subset of orders has item-level rows, so item-based revenue and order-level revenue can differ.
Raw quirks are intentionally kept so the staging layer and tests have real cleaning work to do.
12. Next steps
Add incremental models for large fact tables.
Add source freshness checks and a scheduled Databricks Workflow job.
Build a Power BI dashboard on the gold tables.
Add CI to run dbt build on pull requests.

#13. Author

Haider Ali Khan: data professional with a background in telecom and an MSc in Management with Data Analytics


