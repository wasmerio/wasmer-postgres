use pg_extend::pg_magic;

pg_magic!(version: pg_sys::PG_VERSION_NUM);

mod foreign_data_wrapper;
mod instance;
