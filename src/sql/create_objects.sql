/*Create staging table*/
CREATE TABLE IF NOT EXISTS public.stg_trip_data (
    region VARCHAR(150) NULL,
    origin_coord VARCHAR(500) NULL,
    destination_coord VARCHAR(500) NULL,
    date_time VARCHAR(50) NULL,
    datasource VARCHAR(150) NULL,
    trip_key VARCHAR NULL
);

/*Create historical table to store trip data*/
CREATE TABLE IF NOT EXISTS public.hist_trip_data (
    region VARCHAR(150) NULL,
    origin_coord VARCHAR(500) NULL,
    destination_coord VARCHAR(500) NULL,
    date_time VARCHAR(50) NULL,
    datasource VARCHAR(150) NULL,
    trip_key VARCHAR NULL
);

/*Create unique index to handle updates*/
CREATE UNIQUE INDEX IF NOT EXISTS idx_trip_key on public.hist_trip_data (trip_key);

/*Create materialized view to get average trips per weeks by region*/
CREATE MATERIALIZED VIEW IF NOT EXISTS summarized_trip_data AS
select wa.region, 
       wa.week_of_month, 
       ceil(avg(count)) as weekly_avg 
from (select region, 
            CONCAT(to_char(cast(date_time as date),'YYYY-MM'), 
                    '-0', TO_CHAR(cast(date_time as date), 'W' )::integer) as week_of_month, 
            count(*) as count 
    from public.hist_trip_data group by region, CONCAT(to_char(cast(date_time as date),'YYYY-MM'), 
                                                        '-0', TO_CHAR(cast(date_time as date), 'W' )::integer)) as wa 
group by wa.region, wa.week_of_month;