# Build the `wasmer` extension.
build:
	PG_INCLUDE_PATH=$(pg_config --includedir-server) cargo build --release

# Test the `wasmer` extension.
test POSTGRES_USER='$USER' POSTGRES_DB='postgres':
	PG_INCLUDE_PATH=$(pg_config --includedir-server) \
	POSTGRES_USER={{POSTGRES_USER}} \
	POSTGRES_DB={{POSTGRES_DB}} \
		cargo test

# Initialize Postgres.
pg-init:
	pg_ctl init -D $(pwd)/tests/pg

# Start Postgres.
pg-start:
	pg_ctl start -D $(pwd)/tests/pg -l $(pwd)/tests/pg/pg.log

# Stop Postgres.
pg-stop:
	pg_ctl stop -D $(pwd)/tests/pg 

# Start a shell into Postgres.
pg-shell:
	psql -d postgresql://$USER@localhost:5432/postgres

pg-run-one-file FILE:
	sed -e "s,%cwd%,$(pwd)," {{FILE}} | psql -d postgres | sed -e "s,$(pwd),%cwd%,"

# Local Variables:
# mode: makefile
# End:
