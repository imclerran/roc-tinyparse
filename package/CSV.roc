module [float, integer, csv_string]

import Parser exposing [Parser, number, char, maybe, string, rhs, lhs, both, map, one_or_more, excluding, one_of]
import Utils exposing [int_pair_to_float, approx_eq]

float : Parser F64 [InvalidFloat]
float = |str|
    parser = number |> both(maybe(string(".") |> rhs(number))) |> map(|(l, maybe_r)|
        when maybe_r is
            None -> Ok(Num.to_f64(l))
            Some(r) -> Ok(int_pair_to_float(l, r))
    )
    parser(str) |> Result.map_err(|_| InvalidFloat)

expect
    import Unsafe
    res = float("123.456789") |> Unsafe.unwrap("Failed to parse float")
    approx_eq(res.0, 123.456789)

expect
    import Unsafe
    res = float("123") |> Unsafe.unwrap("Failed to parse float")
    approx_eq(res.0, 123)

integer : Parser U64 [InvalidInteger]
integer = |str|
    number(str) |> Result.map_err(|_| InvalidInteger)

expect
    integer("123") == Ok((123, ""))

csv_string : Parser Str [InvalidString]
csv_string = |str|
    parser = one_of([quoted_string, unquoted_string])
    parser(str) |> Result.map_err(|_| InvalidString)

unquoted_string : Parser Str [InvalidUnquotedString]
unquoted_string = |str|
    pattern = one_or_more(char |> excluding(|c| List.contains([',', '\n', '\r', '\"'], c))) 
    parser = pattern |> map(|chars|
        Ok(Str.from_utf8_lossy(chars))
    )
    parser(str) |> Result.map_err(|_| InvalidUnquotedString)

expect
    unquoted_string("Hello, world!") == Ok(("Hello", ", world!"))

quoted_string : Parser Str [InvalidQuotedString]
quoted_string = |str|
    pattern = string("\"") |> rhs(one_or_more(character)) |> lhs(string("\""))
    parser = pattern |> map(|chars| Ok(Str.from_utf8_lossy(chars)))
    parser(str) |> Result.map_err(|_| InvalidQuotedString)

expect
    quoted_string("\"Hello, \"\"world!\"\"\"") == Ok(("Hello, \"world!\"", ""))

character : Parser U8 [CharNotFound]
character = |str|
    parser = one_of([escaped_quote_character, character_excluding_invalid])
    parser(str) |> Result.map_err(|_| CharNotFound)

expect character("a") == Ok(('a', ""))
expect character("\"\"") == Ok(('\"', ""))
expect character("\"") == Err(CharNotFound)
expect character("\n") == Err(CharNotFound)

character_excluding_invalid : Parser U8 [CharNotFound]
character_excluding_invalid = |str|
    excluded_characters = ['\"', '\n', '\r']
    parser = char |> excluding(|c| List.contains(excluded_characters, c))
    parser(str) |> Result.map_err(|_| CharNotFound)

expect character_excluding_invalid("a") == Ok(('a', ""))
expect character_excluding_invalid("\"") == Err(CharNotFound)
expect character_excluding_invalid("\n") == Err(CharNotFound)
expect character_excluding_invalid("\r") == Err(CharNotFound)

escaped_quote_character : Parser U8 [EscapedQuoteNotFound]
escaped_quote_character = |str|
    parser = string("\"\"") |> map(|_| Ok('\"'))
    parser(str) |> Result.map_err(|_| EscapedQuoteNotFound)

expect escaped_quote_character("\"\"") == Ok(('\"', ""))
expect escaped_quote_character("\" \"") == Err(EscapedQuoteNotFound)
expect escaped_quote_character("\"") == Err(EscapedQuoteNotFound)
