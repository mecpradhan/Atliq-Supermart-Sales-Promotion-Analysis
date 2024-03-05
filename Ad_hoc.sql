## Business Request 1
-- base price greater than 500 and featured in the promo type of 'BOGOF' (buy one get one free)

SELECT 
    p.product_code,
    p.product_name,
    p.category,
    e.base_price,
    e.promo_type
FROM 
    dim_products p
JOIN 
    fact_events e 
ON p.product_code = e.product_code
WHERE 
    e.base_price > 500 and e.promo_type = 'BOGOF';

## Business Request 2
-- Numer of stores in each city (Result in descending order of store count)

select 
city, count(*) as count
from dim_stores
group by city
order by count desc;

## Business Request 3
-- Report to generate each campaign along with total revenue generated before and after campaign

with cte1 as( select
c.campaign_name,
e.promo_type,
sum(base_price*`quantity_sold(before_promo)`) as sales_before_promo,
case 
	when promo_type='50% off' then round(sum((base_price*0.5)*`quantity_sold(after_promo)`),1)
    when promo_type='25% off' then round(sum((base_price*0.75)*`quantity_sold(after_promo)`),1)
    when promo_type='33% off' then round(sum((base_price*0.67)*`quantity_sold(after_promo)`),1)
    when promo_type='BOGOF' then round(sum((base_price*0.5)*2*`quantity_sold(after_promo)`),1)
    when promo_type='500 cashback' then round(sum((base_price-500)*`quantity_sold(after_promo)`),1)
    else round(sum(base_price*`quantity_sold(after_promo)`),1) end as sales_after_promo
from fact_events e
inner join dim_campaigns c
on
c.campaign_id=e.campaign_id
group by campaign_name,promo_type)
select
campaign_name,
round(sum(sales_before_promo)/1000000,2) as total_revenue_bf_promo_mln,
round(sum(sales_after_promo)/1000000,2) as revenue_af_promo_mln
from cte1
group by campaign_name;


## Business Request 4
-- Calcuates incremental sold quantity(ISU%) for each category during diwali campaign. Provide ranking for categories based on ISU%
with cte2 as(
select
p.category,
sum(`quantity_sold(after_promo)`) as quantity_after_promo,
sum(`quantity_sold(before_promo)`)as quantity_before_promo
from fact_events e
join dim_products p
on p.product_code=e.product_code
where campaign_id="CAMP_DIW_01"
group by category)

select
	category,
    round(((quantity_after_promo  - quantity_before_promo) /quantity_before_promo)*100,2) as ISU_percent ,
        rank() over( order by (quantity_after_promo  - quantity_before_promo) /quantity_before_promo  Desc ) as ISU_percent_rank_order
    FROM cte2;

## Business Request 5
-- Report featuring Top 5 product based on Increment revenue percentage(IR%) across all campaign 

with cte3 as(
select
	p.product_name,
    p.category,
    e.base_price,
	`quantity_sold(after_promo)` as quantity_after_promo,
	`quantity_sold(before_promo)`as quantity_before_promo,
case
    when promo_type = "50% off" then base_price * 0.50
	when promo_type = "25% off" then base_price * 0.75
	when promo_type = "bogof" then base_price * 0.50
	when promo_type = "500 cashback" then (base_price - 500)
    when promo_type = "33% off" then base_price * 0.67
	else base_price
	end as new_promo_price
from fact_events e
join dim_products p
on p.product_code=e.product_code
),    
cte4 as(
select
	product_name,
    category,
    sum(base_price*quantity_before_promo) as revenue_before,
    sum(new_promo_price*quantity_after_promo) as revenue_after
from cte3
group by category,product_name),
cte5 as (
select	
	category,
    product_name,
    round((revenue_after - revenue_before)/1000000,1) as ir_mln,
	round(((revenue_after - revenue_before)/ revenue_before)*100,1) as ir_per
    from cte4
    )
select 
*,
rank () over(order by IR_per desc) as ir_rank from cte5 limit 5;
