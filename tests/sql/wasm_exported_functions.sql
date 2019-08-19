BEGIN TRANSACTION;

SELECT wasm_new_instance('%cwd%/tests/wasm/tests.wasm', 'test');

SELECT pg_typeof(x) AS type, x FROM (SELECT test_sum(1, 2) AS x) AS T;
SELECT pg_typeof(x) AS type, x FROM (SELECT test_arity_0() AS x) AS T;
SELECT pg_typeof(x) AS type, x FROM (SELECT test_i32_i32(7) AS x) AS T;
SELECT pg_typeof(x) AS type, x FROM (SELECT test_i64_i64(7) AS x) AS T;
SELECT pg_typeof(x) AS type, x FROM (SELECT test_bool_casted_to_i32() AS x) AS T;
SELECT pg_typeof(x) AS type, x FROM (SELECT test_string() AS x) AS T;
SELECT pg_typeof(x) AS type, x FROM (SELECT test_void() AS x) AS T;

ROLLBACK;
