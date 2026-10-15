-- Non-Negative Values
select
    order_id,
    revenue
from {{ ref('fct_orders') }}
where revenue < 0
