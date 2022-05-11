/*BULK INSERT csv to staging*/
COPY public.stg_trip_data ( region, 
                            origin_coord, 
                            destination_coord, 
                            date_time, 
                            datasource)
FROM '/var/lib/postgresql/data/trips.csv' DELIMITER ',' CSV HEADER;

/*Create a UNIQUE INDEX that will be used to upsert from stg to hist*/
UPDATE public.stg_trip_data
SET trip_key = CONCAT(region, origin_coord, destination_coord, date_time, datasource);

/*upsert from staging to hist*/
INSERT INTO public.hist_trip_data(region, 
                                  origin_coord, 
                                  destination_coord, 
                                  date_time, 
                                  datasource,
                                  trip_key)
SELECT region, 
       origin_coord, 
       destination_coord, 
       date_time, 
       datasource,
       trip_key
FROM public.stg_trip_data
ON CONFLICT (trip_key)
DO NOTHING;

/*Clean staging for next batch*/
TRUNCATE TABLE public.stg_trip_data;