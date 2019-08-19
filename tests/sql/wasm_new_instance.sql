BEGIN TRANSACTION;

SELECT wasm_new_instance('%cwd%/tests/wasm/tests.wasm', 'test');

SELECT * FROM wasm.instances;
SELECT * FROM wasm.exported_functions;

ROLLBACK;
