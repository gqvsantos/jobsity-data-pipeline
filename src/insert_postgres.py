#!/usr/bin/python
import pyspark

if __name__ == '__main__':
    sc = pyspark.SparkContext(appName='load_stg_postgres')

    table = 'public.stg_trip_data'
    csv_source = '/data/trips.csv'

    try:
        session = pyspark.sql.SparkSession(sc)

        jdbc_url = 'jdbc:postgresql://postgres/postgres'
        connection_properties = {
            'user': 'postgres',
                    'password': 'postgres',
                    'driver': 'org.postgresql.Driver',
                    'stringtype': 'unspecified'}

        df = session.read.option("delimiter", ",").option("header", "true").csv(csv_source)
        df.show()
        df.write.jdbc(jdbc_url, table, connection_properties)
    except:
        print('Error loading data from ',csv_source,'into ', table, '. Please refer to Spark log.')
    finally:
        sc.stop()
