# Build the `wasmer` extension.
build:
	PG_INCLUDE_PATH=$(pg_config --includedir-server) cargo build --release

# Test the `wasmer` extension.
test:
	PG_INCLUDE_PATH=$(pg_config --includedir-server) cargo test

# Initialize Postgres.
pg-init:
	pg_ctl init -D $(pwd)/test/pg

# Start Postgres.
pg-start:
	pg_ctl start -D $(pwd)/test/pg -l $(pwd)/test/pg/pg.log

# Stop Postgres.
pg-stop:
	pg_ctl stop -D $(pwd)/test/pg 

# Start a shell into Postgres.
pg-shell:
	psql -d postgres

# Local Variables:
# mode: makefile
# End:
