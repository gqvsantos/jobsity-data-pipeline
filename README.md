# Building a pipeline to ingest, process and store trip data

## Overview

This approach intends to simulate a cloud cluster environment (Dataproc / EMR), and for this we'll be using docker compose to create two worker nodes, each one with dedicated 1GB memory for parallel processing.

For development:

* A Postgres database to persist datasets.
* A Spark cluster with two worker nodes.

The Docker setup has a `develop` network where all of the containers run. To support development Spark UI is exposed on 8100 and Jupyter is on 9999, the decision to use non-standard ports is to avoid conflicts with anything running on the host.

## Building the environment

To speed up the process, there's a Makefile with ready-to-run commands.

```bash
# Clone the repository
git clone https://github.com/gquevin/jobsity-data-pipeline.git

# Create the environment
cd jobsity-data-pipeline
make all
```

## Spark - Files

The Spark container mount the hosts `/tmp` folder to `/data`. The mount acts as a shared file system accessible to both Spark and Postgres. In a production environment cloud storage / S3 would be used.

## Spark - Tables

It's possible to create the table at runtime based on a dataframe with the following approach:

```python
from sqlalchemy import create_engine
engine = create_engine('postgresql://username:password@host:port/database')
df.to_sql('table_name', engine)
```

But this is discouraged since it would bind the table specifications (field size, data type) to the data within. Data should be table-oriented and not the other way around. 

With that in mind, the load will occur on a previously created staging table:

[Based on the official Postgres documentation, the approach to load the data will be COPY](https://www.postgresql.org/docs/current/populate.html#POPULATE-COPY-FROM)


```sql
CREATE TABLE public.trip_data (
region VARCHAR(150) NULL,
origin_coord VARCHAR(500) NULL,
destination_coord VARCHAR(500) NULL,
date_time VARCHAR(150) NULL,
datasource VARCHAR(150) NULL
);
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
