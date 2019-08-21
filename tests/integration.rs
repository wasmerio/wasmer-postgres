use std::{
    env::var,
    ffi::OsStr,
    fs,
    io::Write,
    path::Path,
    process::{Command, Stdio},
};

#[test]
fn sql_vs_expected_output() {
    let pwd = var("PWD").expect("Cannot read `$PWD`.");
    let psql_h = &format!("{cwd}/tests/pg", cwd = pwd);
    Command::new("psql")
        .args(&["-h", psql_h, "-d", "postgres", "-f", "src/wasm.sql"])
        .output()
        .expect("Failed to run `src/wasm.sql` with `psql");

    let fixtures_directory = Path::new("./tests/sql");
    let sql = OsStr::new("sql");

    for entry in fs::read_dir(fixtures_directory).unwrap() {
        let entry = entry.unwrap();
        let input_path = entry.path();

        if let Some(extension) = input_path.extension() {
            if extension == sql {
                let input_content = fs::read_to_string(&input_path)
                    .unwrap()
                    .replace("%cwd%", &pwd);
                let mut psql = Command::new("psql")
                    .args(&["-h", psql_h, "-d", "postgres"])
                    .stdin(Stdio::piped())
                    .stdout(Stdio::piped())
                    .stderr(Stdio::piped())
                    .spawn()
                    .unwrap();
                psql.stdin
                    .as_mut()
                    .ok_or("`psql` stdin has not been captured.")
                    .unwrap()
                    .write_all(input_content.as_bytes())
                    .unwrap();

                let output = psql.wait_with_output().unwrap();
                let raw_output = if output.status.success() {
                    unsafe { String::from_utf8_unchecked(output.stdout) }
                } else {
                    panic!("Failed to retrieve the output of `psql`.");
                };

                let expected_path = input_path.as_path().with_extension("expected_output");
                let expected_output = fs::read_to_string(&expected_path)
                    .unwrap()
                    .replace("%cwd%", &pwd);

                assert_eq!(
                    raw_output, expected_output,
                    "The queries in `{:?}` does not produce the expected output in `{:?}`.",
                    input_path, expected_path,
                );
            }
        }
    }
}
