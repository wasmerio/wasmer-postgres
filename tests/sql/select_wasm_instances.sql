BEGIN TRANSACTION;

SELECT * FROM wasm.instances;

SELECT wasm_new_instance('%cwd%/examples/simple.wasm', 'ns');

SELECT * FROM wasm.instances;

ROLLBACK;
