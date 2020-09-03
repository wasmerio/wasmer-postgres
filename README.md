# <img height="48" src="https://wasmer.io/static/icons/favicon-96x96.png" alt="Wasmer logo" valign="middle"> Wasmer Postgres [Wasmer Slack Channel](https://img.shields.io/static/v1?label=chat&message=on%20Slack&color=green)](https://slack.wasmer.io)

A complete and mature WebAssembly runtime for Postgres based on [Wasmer].
It's an original way to extend your favorite database capabilities.

Features:

  * **Easy to use**: The `wasmer` API mimics the standard WebAssembly API,
  * **Fast**: `wasmer` executes the WebAssembly modules as fast as
    possible, close to **native speed**,
  * **Safe**: All calls to WebAssembly will be fast, but more
    importantly, completely safe and sandboxed.

> Note: The project is still in heavy development. This is a
0.1.0 version. Some API are missing and are under implementation. But
it's fun to play with it.

# Installation

The project comes in two parts:

  1. A shared library, and
  2. A PL/pgSQL extension.
  
To compile the former, run `just build` (Postgres server headers are
required, see `pg_config --includedir-server`). To install the latter,
run `just install`. After that, run `CREATE EXTENSION wasm` in a
Postgres shell. A new function will appear: `wasm_init`; it must be
called with the absolute path to the shared library. It looks like
this:

```shell
$ # Build the shared library.
$ just build

$ # Install the extension in the Postgres tree.
$ just install

$ # Activate and initialize the extension.
$ just host=$host database=$database activate
```

And you are ready to go!

*Note*: On macOS, the shared library extension is `.dylib`, on Windows,
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
