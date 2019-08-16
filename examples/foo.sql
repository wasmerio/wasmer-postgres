--
-- Instances Foreign Data Wrapper
--

CREATE OR REPLACE FUNCTION InstancesForeignDataWrapper() RETURNS fdw_handler AS '/Users/hywan/Development/Wasmer/pg-ext-wasm/target/release/libpg_ext_wasm.dylib', 'fdw_InstancesForeignDataWrapper' LANGUAGE C STRICT;

DROP FOREIGN DATA WRAPPER IF EXISTS InstancesForeignDataWrapper CASCADE;
CREATE FOREIGN DATA WRAPPER InstancesForeignDataWrapper handler InstancesForeignDataWrapper NO VALIDATOR;

DROP SERVER IF EXISTS wasm_instances CASCADE;
CREATE SERVER wasm_instances FOREIGN DATA WRAPPER InstancesForeignDataWrapper;

--
-- Exported Functions Foreign Data Wrapper
--

CREATE OR REPLACE FUNCTION ExportedFunctionsForeignDataWrapper() RETURNS fdw_handler AS '/Users/hywan/Development/Wasmer/pg-ext-wasm/target/release/libpg_ext_wasm.dylib', 'fdw_ExportedFunctionsForeignDataWrapper' LANGUAGE C STRICT;

DROP FOREIGN DATA WRAPPER IF EXISTS ExportedFunctionsForeignDataWrapper CASCADE;
CREATE FOREIGN DATA WRAPPER ExportedFunctionsForeignDataWrapper handler ExportedFunctionsForeignDataWrapper NO VALIDATOR;

DROP SERVER IF EXISTS wasm_exported_functions CASCADE;
CREATE SERVER wasm_exported_functions FOREIGN DATA WRAPPER ExportedFunctionsForeignDataWrapper;

--
-- Foreign Data Wrapper final Schema.
--

DROP SCHEMA IF EXISTS wasm CASCADE;
CREATE SCHEMA wasm;

IMPORT FOREIGN SCHEMA wasm_instances FROM SERVER wasm_instances INTO wasm;
IMPORT FOREIGN SCHEMA wasm_exported_functions FROM SERVER wasm_exported_functions INTO wasm;

SELECT * FROM wasm.instances;

CREATE OR REPLACE FUNCTION new_instance(text) RETURNS text AS '/Users/hywan/Development/Wasmer/pg-ext-wasm/target/release/libpg_ext_wasm.dylib', 'pg_new_instance' LANGUAGE C STRICT;
SELECT new_instance('/Users/hywan/Development/Wasmer/pg-ext-wasm/examples/simple.wasm');
SELECT * FROM wasm.instances;
SELECT * FROM wasm.exported_functions;

--CREATE OR REPLACE FUNCTION invoke_function_2(text, text, int, int) RETURNS int AS '/Users/hywan/Development/Wasmer/pg-ext-wasm/target/release/libpg_ext_wasm.dylib', 'pg_invoke_function_2' LANGUAGE C STRICT;
