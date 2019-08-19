SET plpgsql.extra_warnings TO 'shadowed_variables';

CREATE OR REPLACE FUNCTION wasm_init(dylib_pathname text) RETURNS boolean AS $$
DECLARE
    wasm_schema_name CONSTANT text := 'wasm';
BEGIN
    --
    -- Instances Foreign Data Wrapper
    --
    BEGIN
        EXECUTE format(
            'CREATE OR REPLACE FUNCTION wasm__instances_foreign_data_wrapper() RETURNS fdw_handler AS ''%s'', ''fdw_InstancesForeignDataWrapper'' LANGUAGE C STRICT',
            dylib_pathname
        );
        DROP FOREIGN DATA WRAPPER IF EXISTS wasm__instances_foreign_data_wrapper CASCADE;
        CREATE FOREIGN DATA WRAPPER wasm__instances_foreign_data_wrapper handler wasm__instances_foreign_data_wrapper NO VALIDATOR;

        DROP SERVER IF EXISTS wasm_instances CASCADE;
        CREATE SERVER wasm_instances FOREIGN DATA WRAPPER wasm__instances_foreign_data_wrapper;
    END;

    --
    -- Exported Functions Foreign Data Wrapper
    --
    BEGIN
        EXECUTE format(
            'CREATE OR REPLACE FUNCTION wasm__exported_functions_foreign_data_wrapper() RETURNS fdw_handler AS ''%s'', ''fdw_ExportedFunctionsForeignDataWrapper'' LANGUAGE C STRICT',
            dylib_pathname
        );
        DROP FOREIGN DATA WRAPPER IF EXISTS wasm__exported_functions_foreign_data_wrapper CASCADE;
        CREATE FOREIGN DATA WRAPPER wasm__exported_functions_foreign_data_wrapper handler wasm__exported_functions_foreign_data_wrapper NO VALIDATOR;

        DROP SERVER IF EXISTS wasm_exported_functions CASCADE;
        CREATE SERVER wasm_exported_functions FOREIGN DATA WRAPPER wasm__exported_functions_foreign_data_wrapper;
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
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_1(text, text, bigint) RETURNS int AS ''%s'', ''pg_invoke_function_1'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_2(text, text, bigint, bigint) RETURNS int AS ''%s'', ''pg_invoke_function_2'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_3(text, text, bigint, bigint, bigint) RETURNS int AS ''%s'', ''pg_invoke_function_3'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_4(text, text, bigint, bigint, bigint, bigint) RETURNS int AS ''%s'', ''pg_invoke_function_4'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_5(text, text, bigint, bigint, bigint, bigint, bigint) RETURNS int AS ''%s'', ''pg_invoke_function_5'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_6(text, text, bigint, bigint, bigint, bigint, bigint, bigint) RETURNS int AS ''%s'', ''pg_invoke_function_6'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_7(text, text, bigint, bigint, bigint, bigint, bigint, bigint, bigint) RETURNS int AS ''%s'', ''pg_invoke_function_7'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_8(text, text, bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint) RETURNS int AS ''%s'', ''pg_invoke_function_8'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_9(text, text, bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint) RETURNS int AS ''%s'', ''pg_invoke_function_9'' LANGUAGE C STRICT', dylib_pathname);
    EXECUTE format('CREATE OR REPLACE FUNCTION wasm__invoke_function_10(text, text, bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint) RETURNS int AS ''%s'', ''pg_invoke_function_10'' LANGUAGE C STRICT', dylib_pathname);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION wasm_new_instance(module_pathname text, namespace text) RETURNS text AS $$
DECLARE
    current_instance_id text;
    exported_function RECORD;
    exported_function_generated_inputs text;
    exported_function_generated_outputs text;
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
            CASE
                WHEN length(inputs) = 0 THEN 0
                ELSE array_length(regexp_split_to_array(inputs, ','), 1)
            END AS input_arity,
            outputs
        FROM
            wasm.exported_functions
        WHERE
            instance_id = current_instance_id
    LOOP
        IF exported_function.input_arity > 10 THEN
           RAISE EXCEPTION 'WebAssembly exported function `%` has an arity greater than 10, which is not supported yet.', exported_function.name;
        END IF;

        exported_function_generated_inputs := '';
        exported_function_generated_outputs := '';

        FOR nth IN 1..exported_function.input_arity LOOP
            exported_function_generated_inputs := exported_function_generated_inputs || format(', CAST($%s AS bigint)', nth);
        END LOOP;

        IF length(exported_function.outputs) > 0 THEN
            exported_function_generated_outputs := exported_function.outputs;
        ELSE
            exported_function_generated_outputs := 'integer';
        END IF;

        EXECUTE format(
            'CREATE OR REPLACE FUNCTION %I_%I(%3$s) RETURNS %5$s AS $F$' ||
            'DECLARE' ||
            '    output %5$s;' ||
            'BEGIN' ||
            '    SELECT wasm__invoke_function_%4$s(''%6$s'', ''%2$s''%7$s) INTO STRICT output;' ||
            '    RETURN output;' ||
            'END;' ||
            '$F$ LANGUAGE plpgsql;',
            namespace, -- 1
            exported_function.name, -- 2
            exported_function.inputs, -- 3
            exported_function.input_arity, -- 4
            exported_function_generated_outputs, -- 5
            current_instance_id, -- 6
            exported_function_generated_inputs -- 7
        );
    END LOOP;

    RETURN current_instance_id;
END;
$$ LANGUAGE plpgsql;
