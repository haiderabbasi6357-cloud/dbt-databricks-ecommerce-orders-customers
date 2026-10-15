
-- cleaning products raw
with main as (
    select * from {{ ref('raw_products') }}
),
rename as (
    select
        product_id,
        trim(product_name) as product_name,
        trim(category) as category,
        cast(price as decimal(12, 2)) as price
    from main
)
select * from rename
