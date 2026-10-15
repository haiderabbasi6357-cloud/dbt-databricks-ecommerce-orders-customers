--First Model

with main as (
    select * from {{ ref('raw_order_items') }}
),

rename as (
    select
        order_item_id,
        order_id,
        product_id,
        cast(quantity as int) as quantity,
        cast(unit_price as decimal(12, 2)) as unit_price
    from main
)

select * from rename
