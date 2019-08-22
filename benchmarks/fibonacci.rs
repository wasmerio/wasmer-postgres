#[no_mangle]
pub extern "C" fn fibonacci(n: u32) -> u64 {
    if n <= 0 {
        0
    } else if n == 1 {
        1
    } else {
        let mut accumulator = 0;
        let mut last = 0;
        let mut current = 1;

        for _i in 1..n {
            accumulator = last + current;
            last = current;
            current = accumulator;
        }

        accumulator
    }
}
