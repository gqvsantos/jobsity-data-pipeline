# Building a pipeline to ingest, process and store trip data

## Overview

This approach intends to simulate a cloud cluster environment (Dataproc / EMR), and for this we'll be using docker compose to create two worker nodes, each one with dedicated 1GB memory for parallel processing and also a postgres database for data persistence.

For development:

* A Postgres database to persist datasets.
* A Spark cluster with two worker nodes.

The Docker setup has a `develop` network where all of the containers run. To support development Spark UI is exposed on 8100 and Jupyter is on 9999, the decision to use non-standard ports is to avoid conflicts with anything running on the host.

## Building the environment

To speed up the process, there's a Makefile with ready-to-run commands.

```bash
# Clone the repository
git clone https://github.com/gqvsantos/jobsity-data-pipeline.git

# Create the environment
cd jobsity-data-pipeline
make all
```

Following best practices of infrastructure as code, by triggering the `all` command in the Makefile it will mount the environment and load the table sequentially, as a job (ex: cronjob) would do. We can also split the parts and use AirFlow or Prefect to orchestrate it on separated steps.

## Spark - Files

The Spark container mount the host's `/tmp` folder to `/data`. The mount acts as a shared file system accessible to both Spark and Postgres. In a production environment cloud storage / S3 would be used.

## Spark - Tables

We could've created a Postgres table at runtime based on a dataframe with some approaches like:

```python
from sqlalchemy import create_engine
engine = create_engine('postgresql://username:password@host:port/database')
df.to_sql('table_name', engine)
```

But this is discouraged since it would bind the table specifications (field size, data type) to the data within. Data should be table-oriented and not the other way around. 

With that in mind, the load will occur on a previously created staging table:

[Based on the official Postgres documentation, the approach to load the data will be COPY](https://www.postgresql.org/docs/current/populate.html#POPULATE-COPY-FROM)

First we create `.sql` file called `create_objects` to store our DCLs and DMLs. These files will be stored in src/sqls directory.

```sql
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

/*Create materialized view to get average trips per weeks by region
This will return YEAR-MONTH-WEEK, the region and the average trips for that region that week*/
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
```

Second step is creating another `.sql` file called `populate_postgres` which will transfer de CSV data to the staging table and after this, upsert the data to our historical table.

```sql
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
```

### Calculating the Frequencies With Spark

```python
import pyspark

conf = pyspark.SparkConf().setAppName('Postgres').setMaster('spark://spark:7077')
sc = pyspark.SparkContext(conf=conf)
session = pyspark.sql.SparkSession(sc)

jdbc_url = 'jdbc:postgresql://postgres/postgres'
connection_properties = {
'user': 'postgres',
'password': 'postgres',
'driver': 'org.postgresql.Driver',
'stringtype': 'unspecified'}

df = session.read.jdbc(jdbc_url,'public.coin_toss',properties=connection_properties)

samples = df.count()
stats = df.groupBy('outcome').count()

for row in stats.rdd.collect():
print("{} {}%".format(row['outcome'], row['count'] / samples * 100))

sc.stop()
```

## Running A Spark Job

Instead of driving everything from a Jupyter notebook, we can run our Python code directly on Spark by submitting it as a job.

I've packaged the coin toss example as a Python file at `pyspark/src/main.py`.

We can submit the code as a job to spark by running:

```bash
make spark-submit
```
