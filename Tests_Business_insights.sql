--Business Insights countries wtih the Highest revenue

SELECT customer_country, SUM(revenue) AS Revenue FROM gold.fct_orders
GROUP BY (customer_country)


-- Customers with the most Orders and the highest revenue

SELECT customer_id,count(*) AS Orders, SUM(revenue) AS Revenue FROM gold.fct_orders
WHERE status ='delivered'
GROUP BY customer_id
HAVING Revenue > 50
ORDER BY Revenue DESC


-- Categories with the Highest Revenue

select product_category, product_name,sum(revenue)as Total_Revenue from gold.fct_order_items
group by product_category,product_name
order by sum(revenue) desc


-- Highest revenue per month

select date_format(order_date,'MMMM') as months,sum(revenue) as Revenue from gold.fct_order_items
GROUP BY date_format(order_date,'MMMM')
