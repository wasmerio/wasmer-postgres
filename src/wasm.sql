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

    -- Function `wasm__invoke_function_*`
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_0(text, text) RETURNS int AS ''%s'', ''pg_invoke_function_0'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_1(text, text, int) RETURNS int AS ''%s'', ''pg_invoke_function_1'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_1(text, text, int, int) RETURNS int AS ''%s'', ''pg_invoke_function_2'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_1(text, text, int, int, int) RETURNS int AS ''%s'', ''pg_invoke_function_3'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_1(text, text, int, int, int, int) RETURNS int AS ''%s'', ''pg_invoke_function_4'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_1(text, text, int, int, int, int, int) RETURNS int AS ''%s'', ''pg_invoke_function_5'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_1(text, text, int, int, int, int, int, int) RETURNS int AS ''%s'', ''pg_invoke_function_6'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_1(text, text, int, int, int, int, int, int, int) RETURNS int AS ''%s'', ''pg_invoke_function_7'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_1(text, text, int, int, int, int, int, int, int, int) RETURNS int AS ''%s'', ''pg_invoke_function_8'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_1(text, text, int, int, int, int, int, int, int, int, int) RETURNS int AS ''%s'', ''pg_invoke_function_9'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_1(text, text, int, int, int, int, int, int, int, int, int, int) RETURNS int AS ''%s'', ''pg_invoke_function_10'' LANGUAGE C STRICT', dylib_pathname);

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
    FOR
        exported_function
    IN
        SELECT
            name,
            inputs,
            array_length(regexp_split_to_array(inputs, ','), 1) AS input_arity,
            outputs
        FROM
            wasm.exported_functions
        WHERE
            instance_id = current_instance_id
    LOOP
        IF exported_function.input_arity > 10 THEN
           RAISE EXCEPTION 'WebAssembly exported function `%` has an arity greater than 10, which is not supported yet.', exported_function.name;
        END IF;

        EXECUTE format(
            'CREATE OR REPLACE FUNCTION %I_%I(%3$s) RETURNS %5$s AS $F$' ||
            'DECLARE' ||
            '    output %5$s;' ||
            'BEGIN' ||
            '    SELECT wasm__invoke_function_%4$s(''%6$s'', ''%2$s'', $1, $2) INTO STRICT output;' ||
            '    RETURN output;' ||
            'END;' ||
            '$F$ LANGUAGE plpgsql;',
            namespace, -- 1
            exported_function.name, -- 2
            exported_function.inputs, -- 3
            exported_function.input_arity, -- 4
            exported_function.outputs, -- 5
            current_instance_id -- 6
        );
    END LOOP;

    RETURN current_instance_id;
END;
$$ LANGUAGE plpgsql;
