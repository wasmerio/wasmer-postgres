# Build the `wasmer` extension.
build:
	PG_INCLUDE_PATH=$(pg_config --includedir-server) cargo build --release

# Test the `wasmer` extension.
test:
	echo "SELECT wasm_init('$(find $(pwd)/target/release -depth 1 \( -name 'libpg_ext_wasm.dylib' -or -name 'libpg_ext_wasm.so' \))');" > psql -h $(pwd)/tests/pg -d postgres
	PG_INCLUDE_PATH=$(pg_config --includedir-server) cargo test --release

# Initialize Postgres.
pg-init:
	pg_ctl init -D $(pwd)/tests/pg

# Start Postgres.
pg-start:
	pg_ctl -o "-k $(pwd)/tests/pg" start -D $(pwd)/tests/pg -l $(pwd)/tests/pg/pg.log

# Stop Postgres.
pg-stop:
	pg_ctl -o "-k $(pwd)/tests/pg" stop -D $(pwd)/tests/pg

# Start a shell into Postgres.
pg-shell:
	psql -h $(pwd)/tests/pg -d postgres

pg-run-one-file FILE:
	sed -e "s,%cwd%,$(pwd)," {{FILE}} | psql -d postgres | sed -e "s,$(pwd),%cwd%,"

# Local Variables:
# mode: makefile
# End:
