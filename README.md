Just because lol, why not!

# Usage

## Basic example

The following commands will compile the dynamic library, load the
extension, and load the PL/pgSQL library:

```shell
$ just build
$ just pg-init
$ just pg-start
$ just pg-shell
postgres=$ \i src/wasm.sql
```

The next commands (in `pg-shell`) will initialize the extension, and instantiate a
WebAssembly module:

```sql
-- Initialize the extension (must be done once per pgsql instance).
SELECT wasm_init('/absolute/path/to/target/release/libpg_ext_wasm.dylib');

-- Instantiate a WebAssembly module.
SELECT wasm_new_instance('/absolute/path/to/examples/simple.wasm', 'ns');
```

Now, the WebAssembly module has been instantiated, and all its
exported functions have been exported to SQL (prefixed by `ns` as a
namespace). For instance, `simple.wasm` contains a `sum(i32, i32) ->
i32` function, so one can write:

```sql
-- Let's run WebAssembly from SQL!
SELECT ns_sum(1, 2);

--  ns_sum
-- --------
--       3
-- (1 row)
```

## Reflection

Still in `pg-shell`, try running the following commands:

```sql
-- Select all WebAssembly instances.
SELECT * FROM wasm.instances;

--                   id                  |               wasm_file
-- --------------------------------------+----------------------------------------
--  426e17af-c32f-5027-ad73-239e5450dd91 | /absolute/path/to/examples/simple.wasm
-- (1 row)

-- Select all exported functions for a specific instance.
SELECT name, inputs, outputs FROM wasm.exported_functions WHERE instance_id = '426e17af-c32f-5027-ad73-239e5450dd91';

--  name |     inputs      | outputs
-- ------+-----------------+---------
--  sum  | integer,integer | integer
-- (1 row)
```

This reflection mechanism is using foreign schema, and foreign data
wrappers. It is used to create the exported functions in SQL directly.

# Test

To run the test, run the following commands:

```shell
$ just pg-start
$ just test
```

# Cautions

Doesn't work with PostgreSQL 11 yet (see https://github.com/bluejekyll/pg-extend-rs/issues/49).
