
help:
	@echo "build - The Docker image jobsity/spark-postgres"
	@echo "network - Create the develop docker network"
	@echo "postgres - Run a Postres container (exposes port 5432)"
	@echo "copy-file" - Copy file to the working directory (Simulates a download)
	@echo "postgres-create-objects - execute the SQL commands defined in the src/create_table.sql file"
	@echo "postgres-populate - execute the SQL commands defined in the src/populate_postgres.sql file"
	@echo "spark - Run a Spark cluster (exposes port 8100)"
	@echo "spark-submit-insert - Load postgres tables through spark job"


all: default network postgres spark copy-file postgres-create-objects postgres-populate

default: build

build:
	docker build -t jobsity/spark-postgres -f Dockerfile .

network:
	@docker network inspect develop >/dev/null 2>&1 || docker network create develop

copy-file:
	cp trips.csv /tmp/

postgres:
	@docker start postgres > /dev/null 2>&1 || docker run --name postgres \
		--restart unless-stopped \
		--net=develop \
		-e POSTGRES_PASSWORD=postgres \
		-e PGDATA=/var/lib/postgresql/data/pgdata \
		-v /tmp:/var/lib/postgresql/data \
		-p 5432:5432 -d postgres:11

postgres-create-objects:
	cat src/sqls/create_objects.sql | docker exec -i postgres psql -U postgres

postgres-populate:
	cat src/sqls/populate_postgres.sql | docker exec -i postgres psql -U postgres

spark:
	docker-compose up -d

spark-submit-insert:
	cp src/insert_postgres.py /tmp/
	docker exec spark spark-submit --master spark://spark:7077 /data/insert_postgres.py