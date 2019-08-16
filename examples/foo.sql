-- Initializing the extension.
SELECT wasm_init('/Users/hywan/Development/Wasmer/pg-ext-wasm/target/release/libpg_ext_wasm.dylib');

-- Get some fun.
SELECT wasm_new_instance(
    -- Path to the WebAssembly module.
    '/Users/hywan/Development/Wasmer/pg-ext-wasm/examples/simple.wasm',
    -- Namespace/prefix for the exported functions.
    'foo'
);
