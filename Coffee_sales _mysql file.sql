select * from coffee_sales;

-- checking total no. of transactional records and duplicates in transaction_id field 
select count(*),count(distinct transaction_id) from coffee_sales ;

-- data cleaning , date formatting

update coffee_sales 
set transaction_date = STR_TO_DATE(transaction_date ,'%d-%m-%y') ;

alter table coffee_sales 
modify column transaction_date DATE ;

alter table coffee_sales 
modify column transaction_time time ;

alter table coffee_sales
modify column unit_price decimal(8,2) ; 

desc coffee_sales ;

-- checking min. and max. of transaction dates to get the time range between which transactions were recorded 
select
      min(transaction_date) as start_date , 
      max(transaction_date) as last_date 
from coffee_sales ;
       
-- calculate revenue for each store for each month, MoM revenue, MoM revenue_percent
with store_sales as 
 (select 
       store_location,
       month(transaction_date) as month,
       sum(unit_price*transaction_qty) as monthly_revenue
from coffee_sales
group by 1,2
order by store_location,month
) 
, month_over_month as (
select store_sales.*,
       lag(store_sales.monthly_revenue) over (partition by store_sales.store_location order by store_sales.month) as previous_month_revenue,
       (store_sales.monthly_revenue - lag(store_sales.monthly_revenue) over (partition by store_sales.store_location order by store_sales.month)) as mom_revenue 
from store_sales 
)

select month_over_month.store_location,
       month_over_month.month,
       month_over_month.monthly_revenue,
       month_over_month.mom_revenue,
       round((month_over_month.mom_revenue/month_over_month.previous_month_revenue)*100,1) as mom_percent
from month_over_month ;
------------------------------------------------

with base as (select 
     store_location,
     month(transaction_date) as month,
     count(transaction_id) as orders 
from coffee_sales 
group by 1,2 
order by 1,2
) 
,mom_base as (
select 
     base.*,
     lag(base.orders) over (partition by base.store_location order by month asc ) as previous_month_orders,
     base.orders- lag(base.orders) over (partition by base.store_location order by month asc) as mom_orders
from base 
)
select 
      mom_base.store_location,
      mom_base.month,
      mom_base.orders,
      mom_base.mom_orders,
      round((mom_base.mom_orders/mom_base.previous_month_orders)*100,2) as mom_orders_percent
from mom_base ;

-------------------------------------------
-- for each store location in every month, quantity sold ,MoM quantity sold , MoM quantity sold percenatge growth
with base_cte as (
select 
      store_location,
      month(transaction_date) as month,
      sum(transaction_qty) as quantity_sold
from coffee_sales 
group by 1,2
order by 1,2 
)
, quantity_cte as (
 select 
       base_cte.*,
       lag(base_cte.quantity_sold) over(partition by base_cte.store_location order by base_cte.month asc ) as previous_month_quantity,
       base_cte.quantity_sold-lag(base_cte.quantity_sold) over(partition by base_cte.store_location order by base_cte.month asc)
       as mom_quantity_sold
from base_cte
)
select 
       quantity_cte.store_location,
       quantity_cte.month,
       quantity_cte.quantity_sold,
       quantity_cte.mom_quantity_sold,
       round((quantity_cte.mom_quantity_sold/quantity_cte.previous_month_quantity)*100,1) as mom_quantity_percent
from quantity_cte

-------------------------------------------------
-- calculating total revenue, orders and quantity sold on each day across 6 months from calendar heat map 

select transaction_date,
       sum(transaction_qty*unit_price) as revenue ,
       count(transaction_id) as orders ,
       sum(transaction_qty) as quanity_sold
 from coffee_sales 
 where month(transaction_date)= 4 
 group by 1 
 order by 1 asc ;

----------------------------------
-- calculating revenue, orders, quantity sold by weekends vs weekdays 
select 
     case 
     when dayofweek(transaction_date) in (1,7) then 'Weekend'
     else 'Weekday'
     end as day_type,
     sum(transaction_qty*unit_price) as revenue ,
     count(transaction_id) as orders,
     sum(transaction_qty) as quantity_sold
from coffee_sales 
where month(transaction_date) = 2 
group by 1 ;

--------------------------------
-- calculating daily revenue for each month and average of daily revenue fro that month

with daily_rev as (select 
	   month(transaction_date) as month,
       day(transaction_date) as day,
       round(sum(transaction_qty*unit_price),0) as daily_revenue
from coffee_sales 
group by 1,2
) 

select 
       daily_rev.*,
       round(avg(daily_rev.daily_revenue) over(partition by daily_rev.month),0) as monthly_average_revenue
from daily_rev ;

-----------------------------------------------
-- Top 10 products by revenue in each month 

with product_cte as (select 
       month(transaction_date) as month,
       product_detail as product_name,
       round(sum(transaction_qty*unit_price),0) as revenue
from coffee_sales 
group by 1,2
) 
, rank_cte as (
select 
        product_cte.*,
        dense_rank() over(partition by product_cte.month order by product_cte.revenue desc ) as rn
from  product_cte 
) 

select 
       rank_cte.*
from rank_cte
where rank_cte.rn <11 ;
-------------------------------------------
-- calculating the revenue by each weekday of the month 

select 
      month(transaction_date) as month,
      case 
      when dayofweek(transaction_date)=1 then 'Sunday'
      when dayofweek(transaction_date)=2 then 'Monday'
      when dayofweek(transaction_date)=3 then 'Tuesday'
      when dayofweek(transaction_date)=4 then 'Wednesday'
      when dayofweek(transaction_date)=5 then 'Thursday'
      when dayofweek(transaction_date)=6 then 'Friday'
      else 'Saturday'
      end as week_day,
      round(sum(transaction_qty*unit_price),0) as revenue
from coffee_sales 
group by 1,2 ;

--------------------------------------------------
-- revenue by hour of each month 
select 
        month(transaction_date) as month_,
        hour(transaction_time) as hour_,
        round(sum(transaction_qty*unit_price),0) as revenue
from coffee_sales 
group by 1,2
order by 1,2

------------------------------------------------------------------

-- top product_types which bring in 80% of the total monthly revenue in each month (pareto rule)

with product_type_revenue as (select product_type , month(transaction_date) as month , sum(unit_price*transaction_qty) as revenue from coffee_sales 
group by 1,2 
order by product_type asc, month asc  ) 
, month_revenue as (
select month(transaction_date) as month , sum(unit_price*transaction_qty) as monthly_revenue 
from coffee_sales 
group by 1 ) 

, summary as (select m.month, p.product_type,p.revenue as product_type_revenue,m.monthly_revenue,
round((p.revenue/m.monthly_revenue)*100,2) as percent_total
from product_type_revenue p inner join month_revenue m 
on p.month = m.month 
order by m.month asc , product_type_revenue desc ) 
 
select summary.* , 
sum(summary.percent_total) over ( partition by summary.month order by summary.percent_total desc  ) as cumulative_percent_total 
from summary

-----------------------------------------------

-- average order value of stores in each month
select 
     store_location , 
     month(transaction_date) as month ,
     round(avg(transaction_qty* unit_price ),2) as AOV 
from coffee_sales 
group by 1,2 
order by 1,2 



