WITH regions AS (
SELECT region, count(*) as appearance
FROM public.hist_trip_data
GROUP BY region
)

, recurring_regions as (
select region
from regions
order by appearance desc
fetch first 2 rows only)

, latest_datasource as (
select max(cast(date_time as timestamp)) as last_occurence
from recurring_regions as rr 
inner join public.hist_trip_data as htd
on rr.region = htd.region
)

select datasource 
from public.hist_trip_data as htd 
inner join latest_datasource as ltd 
on cast(htd.date_time as timestamp) = ltd.last_occurence 
