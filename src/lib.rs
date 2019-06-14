use pg_extend::{pg_error, pg_magic};
use pg_extern_attr::pg_extern;
use std::{collections::HashMap, fs::File, io::prelude::*, sync::RwLock};
use wasmer_runtime::{imports, instantiate, Instance, Value};
use wasmer_runtime_core::cache::WasmHash;

static mut INSTANCES: Option<RwLock<HashMap<String, Instance>>> = None;

fn get_instances() -> &'static RwLock<HashMap<String, Instance>> {
    unsafe {
        if INSTANCES.is_none() {
            let lock = RwLock::new(HashMap::new());
            INSTANCES = Some(lock);
        }

        &INSTANCES.as_ref().unwrap()
    }
}

pg_magic!(version: pg_sys::PG_VERSION_NUM);

#[pg_extern]
fn new_instance(file: String) -> Option<String> {
    let mut file = match File::open(file) {
        Ok(file) => file,
        Err(_) => return None,
    };

    let mut bytes = Vec::new();

    if let Err(_) = file.read_to_end(&mut bytes) {
        return None;
    }

    let import_object = imports! {};

    match instantiate(bytes.as_slice(), &import_object) {
        Ok(instance) => {
            let mut instances = get_instances().write().unwrap();
            let key = WasmHash::generate(bytes.as_slice()).encode();
            instances.insert(key.clone(), instance);

            Some(key)
        }
        Err(_) => None,
    }
}

#[pg_extern]
fn invoke_function(instance_id: String, function_name: String) -> Option<i64> {
    let instances = get_instances().read().unwrap();

    match instances.get(&instance_id) {
        Some(instance) => {
            let function = match instance.dyn_func(&function_name) {
                Ok(function) => function,
                Err(error) => {
                    pg_error::log(
                        pg_error::Level::Error,
                        file!(),
                        line!(),
                        module_path!(),
                        format!(
                            "Exported function `{}` does not exist in instance `{}`: {}",
                            function_name, instance_id, error
                        ),
                    );

                    return None;
                }
            };

            let results = match function.call(&[Value::I32(1), Value::I32(2)]) {
                Ok(results) => results,
                Err(error) => {
                    pg_error::log(
                        pg_error::Level::Error,
                        file!(),
                        line!(),
                        module_path!(),
                        format!(
                            "Failed to call the `{}` exported function of instance `{}`: {}",
                            function_name, instance_id, error
                        ),
                    );

                    return None;
                }
            };

            if results.len() == 1 {
                match results[0] {
                    Value::I32(value) => Some(value as i64),
                    Value::I64(value) => Some(value),
                    _ => None,
                }
            } else {
                None
            }
        }

        None => {
            pg_error::log(
                pg_error::Level::Error,
                file!(),
                line!(),
                module_path!(),
                format!("Instance with ID `{}` isn't found.", instance_id),
            );

            None
        }
    }
}

#[pg_extern]
fn sum(x: i32, y: i32) -> i32 {
    let mut file =
        File::open("/Users/hywan/Development/Wasmer/pg-ext-wasm/examples/simple.wasm").unwrap();
    let mut bytes = Vec::new();
    file.read_to_end(&mut bytes).unwrap();

    let import_object = imports! {};
    let instance = instantiate(bytes.as_slice(), &import_object).unwrap();

    let values = instance
        .dyn_func("sum")
        .unwrap()
        .call(&[Value::I32(x), Value::I32(y)])
        .unwrap();

    if let Value::I32(value) = values[0] {
        value
    } else {
        0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_greet() {
        assert_eq!(&greet("World".into()), "Hello, World!");
    }

    #[test]
    fn test_sum() {
        assert_eq!(sum(1, 2), 3);
    }
}
