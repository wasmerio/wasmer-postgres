use crate::instance::get_instances;
use pg_extend::{
    pg_datum,
    pg_fdw::{ForeignData, ForeignRow, OptionMap},
    pg_type,
};
use pg_extern_attr::pg_foreignwrapper;

struct Row {
    id: String,
    wasm_file: String,
}

#[pg_foreignwrapper]
struct InstancesForeignDataWrapper {
    inner: Vec<Row>,
}

impl Iterator for InstancesForeignDataWrapper {
    type Item = Box<dyn ForeignRow>;

    fn next(&mut self) -> Option<Self::Item> {
        match self.inner.pop() {
            Some(row) => Some(Box::new(InstanceForeignDataWrapper { inner: row })),
            None => None,
        }
    }
}

impl ForeignData for InstancesForeignDataWrapper {
    fn begin(_sopts: OptionMap, _topts: OptionMap, _table_name: String) -> Self {
        InstancesForeignDataWrapper {
            inner: get_instances()
                .read()
                .unwrap()
                .iter()
                .map(|(instance_id, instance_info)| Row {
                    id: instance_id.clone(),
                    wasm_file: instance_info.wasm_file.clone(),
                })
                .collect(),
        }
    }

    fn schema(
        _server_opts: OptionMap,
        server_name: String,
        _remote_schema: String,
        local_schema: String,
    ) -> Option<Vec<String>> {
        Some(vec![format!(
            "CREATE FOREIGN TABLE {schema}.instances (id text, wasm_file text) SERVER {server}",
            server = server_name,
            schema = local_schema
        )])
    }
}

struct InstanceForeignDataWrapper {
    inner: Row,
}

impl ForeignRow for InstanceForeignDataWrapper {
    fn get_field(
        &self,
        name: &str,
        _typ: pg_type::PgType,
        _opts: OptionMap,
    ) -> Result<Option<pg_datum::PgDatum>, &str> {
        match name {
            "id" => Ok(Some(self.inner.id.clone().into())),
            "wasm_file" => Ok(Some(self.inner.wasm_file.clone().into())),
            _ => Err("Unknown field"),
        }
    }
}
