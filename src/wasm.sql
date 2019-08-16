CREATE OR REPLACE FUNCTION wasm_init(dylib_pathname text) RETURNS boolean AS $$
DECLARE
    wasm_schema_name CONSTANT text := 'wasm';
BEGIN
    --
    -- Instances Foreign Data Wrapper
    --
    BEGIN
        EXECUTE format(
            'CREATE OR REPLACE FUNCTION InstancesForeignDataWrapper() RETURNS fdw_handler AS ''%s'', ''fdw_InstancesForeignDataWrapper'' LANGUAGE C STRICT',
            dylib_pathname
        );
        DROP FOREIGN DATA WRAPPER IF EXISTS InstancesForeignDataWrapper CASCADE;
        CREATE FOREIGN DATA WRAPPER InstancesForeignDataWrapper handler InstancesForeignDataWrapper NO VALIDATOR;

        DROP SERVER IF EXISTS wasm_instances CASCADE;
        CREATE SERVER wasm_instances FOREIGN DATA WRAPPER InstancesForeignDataWrapper;
    END;

    --
    -- Exported Functions Foreign Data Wrapper
    --
    BEGIN
        EXECUTE format(
            'CREATE OR REPLACE FUNCTION ExportedFunctionsForeignDataWrapper() RETURNS fdw_handler AS ''%s'', ''fdw_ExportedFunctionsForeignDataWrapper'' LANGUAGE C STRICT',
            dylib_pathname
        );
        DROP FOREIGN DATA WRAPPER IF EXISTS ExportedFunctionsForeignDataWrapper CASCADE;
        CREATE FOREIGN DATA WRAPPER ExportedFunctionsForeignDataWrapper handler ExportedFunctionsForeignDataWrapper NO VALIDATOR;

        DROP SERVER IF EXISTS wasm_exported_functions CASCADE;
        CREATE SERVER wasm_exported_functions FOREIGN DATA WRAPPER ExportedFunctionsForeignDataWrapper;
    END;

    --
    -- Foreign Schema
    --
    BEGIN
        EXECUTE format('DROP SCHEMA IF EXISTS %s CASCADE', wasm_schema_name);
        EXECUTE format('CREATE SCHEMA %I', wasm_schema_name);

        IMPORT FOREIGN SCHEMA wasm_instances FROM SERVER wasm_instances INTO wasm;
        IMPORT FOREIGN SCHEMA wasm_exported_functions FROM SERVER wasm_exported_functions INTO wasm;
    END;

    --
    -- Function `wasm__new_instance`
    --
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__new_instance(text) RETURNS text AS ''%s'', ''pg_new_instance'' LANGUAGE C STRICT', dylib_pathname);

    -- Function `wasm__invoke_function_2`
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_2(text, text, int, int) RETURNS int AS ''%s'', ''pg_invoke_function_2'' LANGUAGE C STRICT', dylib_pathname);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION wasm_new_instance(module_pathname text, namespace text) RETURNS text AS $$
DECLARE
    current_instance_id text;
    exported_function RECORD;
BEGIN
    -- Create a new instance, and stores its ID in `current_instance_id`.
    SELECT wasm__new_instance(module_pathname) INTO STRICT current_instance_id;

    -- Generate functions for each exported functions from the WebAssembly instance.
    FOR exported_function IN SELECT name, inputs, outputs FROM wasm.exported_functions WHERE instance_id = current_instance_id LOOP
        EXECUTE format(
            'CREATE OR REPLACE FUNCTION %I_%I(%3$s) RETURNS %4$s AS $F$' ||
            'DECLARE' ||
            '    output %4$s;' ||
            'BEGIN' ||
            '    SELECT wasm__invoke_function_2(''%5$s'', ''%2$s'', $1, $2) INTO STRICT output;' ||
            '    RETURN output;' ||
            'END;' ||
            '$F$ LANGUAGE plpgsql;',
            namespace, -- 1
            exported_function.name, -- 2
            exported_function.inputs, -- 3
            exported_function.outputs, -- 4
            current_instance_id -- 5
        );
    END LOOP;

    RETURN current_instance_id;
END;
$$ LANGUAGE plpgsql;
