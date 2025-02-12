module [is_digit, int_pair_to_float, approx_eq]

is_digit : U8 -> Bool
is_digit = |c| c >= '0' and c <= '9'

int_pair_to_float : U64, U64 -> F64
int_pair_to_float = |lhs, rhs| 
    frac_len = rhs |> Num.to_str |> Str.count_utf8_bytes
    lhs_f64 = lhs |> Num.to_f64
    rhs_f64 = Num.to_f64(rhs) / ((Num.pow_int(10, frac_len) |> Num.to_f64))
    lhs_f64 + rhs_f64

approx_eq : F64, F64 -> Bool
approx_eq = |lhs, rhs| Num.abs(lhs - rhs) < 0.000001

expect
    res = int_pair_to_float(123, 456789)
    approx_eq(res, 123.456789)