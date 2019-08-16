use crate::instance::get_instances;
use pg_extend::{
    pg_datum,
    pg_fdw::{ForeignData, ForeignRow, OptionMap},
    pg_type,
};
use pg_extern_attr::pg_foreignwrapper;
use wasmer_runtime::Export;

struct Row {
    instance_id: String,
    name: String,
}

#[pg_foreignwrapper]
struct ExportedFunctionsForeignDataWrapper {
    inner: Vec<Row>,
}

impl Iterator for ExportedFunctionsForeignDataWrapper {
    type Item = Box<ForeignRow>;

    fn next(&mut self) -> Option<Self::Item> {
        match self.inner.pop() {
            Some(row) => Some(Box::new(ExportedFunctionForeignDataWrapper { inner: row })),
            None => None,
        }
    }
}

impl ForeignData for ExportedFunctionsForeignDataWrapper {
    fn begin(_sopts: OptionMap, _topts: OptionMap, _table_name: String) -> Self {
        ExportedFunctionsForeignDataWrapper {
            inner: get_instances()
                .read()
                .unwrap()
                .iter()
                .flat_map(|(instance_id, instance_info)| {
                    instance_info
                        .instance
                        .exports()
                        .filter_map(move |(export_name, export)| match export {
                            Export::Function { .. } => Some(Row {
                                instance_id: instance_id.clone(),
                                name: export_name.clone(),
                            }),
                            _ => None,
                        })
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
            "CREATE FOREIGN TABLE {schema}.exported_functions (instance_id text, name text) SERVER {server}",
            server = server_name,
            schema = local_schema
        )])
    }
}

struct ExportedFunctionForeignDataWrapper {
    inner: Row,
}

impl ForeignRow for ExportedFunctionForeignDataWrapper {
    fn get_field(
        &self,
        name: &str,
        _typ: pg_type::PgType,
        _opts: OptionMap,
    ) -> Result<Option<pg_datum::PgDatum>, &str> {
        match name {
            "instance_id" => Ok(Some(self.inner.instance_id.clone().into())),
            "name" => Ok(Some(self.inner.name.clone().into())),
            _ => Err("Unknown field"),
        }
    }
}
