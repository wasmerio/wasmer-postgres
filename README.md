Just because lol, why not!

# Basic usage

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
SELECT wasm_init('path/to/target/release/libpg_ext_wasm.dylib');

-- Instantiate a WebAssembly module.
SELECT wasm_new_instance('path/to/examples/simple.wasm', 'ns');
```

Now, the WebAssembly module has been instantiated, and all its
exported functions have been exported to SQL (prefixed by `ns` as a
namespace). For instance, `simple.wasm` contains a `sum(i32, i32) ->
i32` function, so one can write:

```sql
-- Let's run WebAssembly from SQL!
SELECT ns_sum(1, 2);
 ns_sum
--------
      3
(1 row)
```

# Cautions

Doesn't work with PostgreSQL 11 yet (see https://github.com/bluejekyll/pg-extend-rs/issues/49).
