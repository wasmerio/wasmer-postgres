<p align="center">
  <a href="https://wasmer.io" target="_blank" rel="noopener noreferrer">
    <img width="400" src="https://raw.githubusercontent.com/wasmerio/wasmer/master/logo.png" alt="Wasmer logo">
  </a>
</p>

<p align="center">
  <a href="https://spectrum.chat/wasmer">
    <img src="https://withspectrum.github.io/badge/badge.svg" alt="Join the Wasmer Community" valign="middle"></a>
  <a href="https://github.com/wasmerio/wasmer/blob/master/LICENSE">
    <img src="https://img.shields.io/github/license/wasmerio/wasmer.svg" alt="License" valign="middle"></a>
</p>

`postgres-ext-wasm` is a Postgres extension for executing WebAssembly
binaries. It's an original way to extend your favorite database
capabilities.

*Current status*: The project is still in heavy development. This is a
0.1.0 version. Some API are missing and are under implementation. But
it's fun to play with it.

# Installation

The project comes in two parts:

  1. A dynamic library, and
  2. A PL/pgSQL library.
  
To compile the former, run `just build` (Postgres server headers are
required, see `pg_config --includedir-server`). The latter is a single
file located in `src/wasm.sql`. Once the PL/pgSQL is loaded, the
`wasm_init` function must be called: its only argument is the absolute
path to the dynamic library. It looks like this:

```shell
$ # Build the dynamic library.
$ just build

$ # Load the PL/pgSQL library.
$ cat src/wasm.sql | \
      psql -h $host -d $database

$ # Initialize the extension.
$ echo "SELECT wasm_init('$(pwd)/target/release/libpg_ext_wasm.dylib');" | \
      psql -h $host -d $database
```

And you are ready to go!

*Note*: On macOS, the dynamic library extension is `.dylib`, on Windows,
it is `.dll`, and on other distributions, it is `.so`.

*Note 2*: Yes, you need [`just`][just].

## Supported Postgres versions

So far, the extension works on Postgres 10 only. It doesn't work with
Postgres 11 _yet_ ([follow this issue if you want to learn
more][pg-extend-rs-issue-49]). Any help is welcomed!

[just]: https://github.com/casey/just/
[pg-extend-rs-issue-49]: https://github.com/bluejekyll/pg-extend-rs/issues/49

# Usage & documentation

Consider the `examples/simple.rs` program:

```rust
#[no_mangle]
pub extern fn sum(x: i32, y: i32) -> i32 {
    x + y
}
```

Once compiled to WebAssembly, one obtains a similar WebAssembly binary
to `examples/simple.wasm` ([download it][download-simple-wasm]). To
use the `sum` exported function, first, create a new instance of the
WebAssembly module, and second, call the `sum` function.

To instantiate a WebAssembly module, the `wasm_new_instance` function
must be used. It has two arguments:

  1. The absolute path to the WebAssembly module, and
  2. A namespace used to prefix exported functions in SQL.

For instance, calling
`wasm_new_instance('/path/to/simple.wasm', 'ns')` will create the
`ns_sum` function that is a direct call to the `sum` exported function
of the WebAssembly instance. Thus:

```sql
-- New instance of the `simple.wasm` WebAssembly module.
SELECT wasm_new_instance('/absolute/path/to/simple.wasm', 'ns');

-- Call a WebAssembly exported function!
SELECT ns_sum(1, 2);

--  ns_sum
-- --------
--       3
-- (1 row)
```

Isn't it awesome? Calling Rust from Postgres through WebAssembly!

Let's inspect a little bit further the `ns_sum` function:

```sql
\x
\df+ ns_sum
Schema              | public
Name                | ns_sum
Result data type    | integer
Argument data types | integer, integer
Type                | normal
Volatility          | volatile
Parallel            | unsafe
Owner               | …
Security            | invoker
Access privileges   |
Language            | plpgsql
Source code         | …
Description         |
```

The Postgres `ns_sum` signature is `(integer, integer) -> integer`,
which maps the Rust `sum` signature `(i32, i32) -> i32`.

So far, only the WebAssembly types `i32`, `i64` and `v128` are
supported; they respectively map to `integer`, `bigint` and `decimal`
in Postgres. Floats are partly implemented for the moment.

[download-simple-wasm]: https://github.com/wasmerio/postgres-ext-wasm/blob/master/examples/simple.wasm

## Inspect a WebAssembly instance

The extension provides two foreign data wrappers, gathered together in
the `wasm` foreign schema:

  * `wasm.instances` is a table with the `id` and `wasm_file` columns,
    respectively for the instance ID, and the path of the WebAssembly
    module,
  * `wasm.exported_functions` is a table with the `instance_id`,
    `name`, `inputs` and `output` columns, respectively for the
    instance ID of the exported function, its name, its input types
    (already formatted for Postgres), and its output types (already
    formatted for Postgres).

Let's see:

```sql
-- Select all WebAssembly instances.
SELECT * FROM wasm.instances;

--                   id                  |          wasm_file
-- --------------------------------------+-------------------------------
--  426e17af-c32f-5027-ad73-239e5450dd91 | /absolute/path/to/simple.wasm
-- (1 row)

-- Select all exported functions for a specific instance.
SELECT
    name,
    inputs,
    outputs
FROM
    wasm.exported_functions
WHERE
    instance_id = '426e17af-c32f-5027-ad73-239e5450dd91';

--   name  |     inputs      | outputs
-- --------+-----------------+---------
--  ns_sum | integer,integer | integer
-- (1 row)
```

# Benchmarks

Benchmarks are useless most of the time, but it shows that WebAssembly
can be a credible alternative to procedural languages such as
PL/pgSQL. Please, don't take those numbers for granted, it can change
at any time, but it shows promising results:

<table>
  <thead>
    <tr>
      <th>Benchmark</th>
      <th>Runtime</th>
      <th align="right">Time (ms)</th>
      <th align="right">Ratio</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="2">Fibonacci (n = 50)</td>
      <td><code>postgres-ext-wasm</code></td>
      <td align="right">0.206</td>
      <td align="right">1×</td>
    </tr>
    <tr>
      <td>PL/pgSQL</td>
      <td align="right">0.431</td>
      <td align="right">2×</td>
    </tr>
    <tr>
      <td rowspan="2">Fibonacci (n = 500)</td>
      <td><code>postgres-ext-wasm</code></td>
      <td align="right">0.217</td>
      <td align="right">1×</td>
    </tr>
    <tr>
      <td>PL/pgSQL</td>
      <td align="right">2.189</td>
      <td align="right">10×</td>
    </tr>
    <tr>
      <td rowspan="2">Fibonacci (n = 5000)</td>
      <td><code>postgres-ext-wasm</code></td>
      <td align="right">0.257</td>
      <td align="right">1×</td>
    </tr>
    <tr>
      <td>PL/pgSQL</td>
      <td align="right">18.643</td>
      <td align="right">73×</td>
    </tr>
  </tbody>
</table>

# Test

Once the library is built, run the following commands:

```shell
$ just pg-start
$ just test
```

# License

The entire project is under the MIT License. Please read [the `LICENSE` file][license].

[license]: https://github.com/wasmerio/wasmer/blob/master/LICENSE
