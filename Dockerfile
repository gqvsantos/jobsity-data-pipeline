#Pulling a image with the needed dependencies for the project
FROM bitnami/spark

#Postgre stable version 
RUN curl https://jdbc.postgresql.org/download/postgresql-42.2.18.jar -o /opt/bitnami/spark/jars/postgresql-42.2.18.jar