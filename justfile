# Build the `wasm` extension.
build:
	PG_INCLUDE_PATH=$(pg_config --includedir-server) cargo build --release

# Install the `wasm` extension
install:
	cd src && make install

# Test the `wasm` extension.
test:
	#!/usr/bin/env bash
	set -euo pipefail
	case "{{os()}}" in
		"macos")
			dylib_extension="dylib"
			;;
		"windows")
			dylib_extension="dll"
			;;
		*)
			dylib_extension="so"
	esac
	echo 'DROP EXTENSION IF EXISTS wasm; CREATE EXTENSION wasm;' | psql -h $(pwd)/tests/pg -d postgres
	echo "SELECT wasm_init('$(pwd)/target/release/libpg_ext_wasm.${dylib_extension}');" | psql -h $(pwd)/tests/pg -d postgres --echo-all
	PG_INCLUDE_PATH=$(pg_config --includedir-server) cargo test --release --tests

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
	sed -e "s,%cwd%,$(pwd)," {{FILE}} | psql -h $(pwd)/tests/pg -d postgres --no-align | sed -e "s,$(pwd),%cwd%,"

# Local Variables:
# mode: makefile
# End:
