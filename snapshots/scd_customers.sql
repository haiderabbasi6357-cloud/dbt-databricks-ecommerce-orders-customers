-- SCD Type 2 (snapshots): when a record changes, such as a customer’s country 
 -- or a product’s price, the old row is closed and a new row is added.

{% snapshot scd_customers %}
{{
    config(
      target_schema='gold',
      unique_key='customer_id',
      strategy='check',
      check_cols=['first_name', 'last_name', 'email', 'country'],
    )
}}
select
    customer_id,
    trim(first_name) as first_name,
    trim(last_name) as last_name,
    lower(trim(email)) as email,
    upper(trim(country)) as country,
    created_at
from {{ ref('raw_customers') }}
{% endsnapshot %}
