use pg_extend::{pg_error, pg_magic};
use pg_extern_attr::pg_extern;
use std::{collections::HashMap, fs::File, io::prelude::*, sync::RwLock};
use wasmer_runtime::{imports, instantiate, Instance, Value};
use wasmer_runtime_core::{cache::WasmHash, types::Type};

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

fn invoke_function(instance_id: String, function_name: String, arguments: &[i64]) -> Option<i64> {
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

            let signature = function.signature();
            let parameters = signature.params();
            let number_of_parameters = parameters.len() as isize;
            let number_of_arguments = arguments.len() as isize;
            let diff: isize = number_of_parameters - number_of_arguments;

            if diff != 0 {
                pg_error::log(
                    pg_error::Level::Error,
                    file!(),
                    line!(),
                    module_path!(),
                    format!(
                        "Failed to call the `{}` exported function of instance `{}`: Invalid number of arguments.",
                        function_name, instance_id
                    ),
                );

                return None;
            }

            let mut function_arguments = Vec::<Value>::with_capacity(number_of_parameters as usize);

            for (parameter, argument) in parameters.iter().zip(arguments.iter()) {
                let value = match parameter {
                    Type::I32 => Value::I32(*argument as i32),
                    Type::I64 => Value::I64(*argument),
                    _ => {
                        pg_error::log(
                            pg_error::Level::Error,
                            file!(),
                            line!(),
                            module_path!(),
                            format!(
                                "Failed to call the `{}` exported function of instance `{}`: Cannot call it because one of its argument expect a float (`f32` or `f64`), and it is not supported yet by the Postgres extension.",
                                function_name, instance_id
                            ),
                        );
                        return None;
                    }
                };

                function_arguments.push(value);
            }

            let results = match function.call(function_arguments.as_slice()) {
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
fn invoke_function_0(instance_id: String, function_name: String) -> Option<i64> {
    invoke_function(instance_id, function_name, &[])
}

#[pg_extern]
fn invoke_function_1(instance_id: String, function_name: String, argument0: i64) -> Option<i64> {
    invoke_function(instance_id, function_name, &[argument0])
}

#[pg_extern]
fn invoke_function_2(
    instance_id: String,
    function_name: String,
    argument0: i64,
    argument1: i64,
) -> Option<i64> {
    invoke_function(instance_id, function_name, &[argument0, argument1])
}

#[pg_extern]
fn invoke_function_3(
    instance_id: String,
    function_name: String,
    argument0: i64,
    argument1: i64,
    argument2: i64,
) -> Option<i64> {
    invoke_function(
        instance_id,
        function_name,
        &[argument0, argument1, argument2],
    )
}

#[pg_extern]
fn invoke_function_4(
    instance_id: String,
    function_name: String,
    argument0: i64,
    argument1: i64,
    argument2: i64,
    argument3: i64,
) -> Option<i64> {
    invoke_function(
        instance_id,
        function_name,
        &[argument0, argument1, argument2, argument3],
    )
}

#[pg_extern]
fn invoke_function_5(
    instance_id: String,
    function_name: String,
    argument0: i64,
    argument1: i64,
    argument2: i64,
    argument3: i64,
    argument4: i64,
) -> Option<i64> {
    invoke_function(
        instance_id,
        function_name,
        &[argument0, argument1, argument2, argument3, argument4],
    )
}
