## This module contains various generic parsers and combinators
module [
    Parser,
    Maybe,
    char,
    digit,
    integer,
    float,
    string,
    whitespace,
    atomic_grapheme,
    map,
    flat_map,
    filter,
    excluding,
    zero_or_more,
    one_or_more,
    zip,
    zip_3,
    zip_4,
    zip_5,
    zip_6,
    maybe,
    or_else,
    one_of,
    lhs,
    rhs,
    both,
    finalize,
    finalize_lazy,
]

import unicode.CodePoint
import Utils exposing [is_digit, int_pair_to_float, approx_eq]

## TYPES ----------------------------------------------------------------------

## ```
## Parser a err : Str -> Result (a, Str) err
## ```
## A Parser is a function which takes a Str and returns a Result containing a tuple of the matched value and the remaining Str after the match, or an error if the match was not found at the beginning of the Str.
## > Note that the matched value which is returned does not need to be a Str, but can be transformed in any way.
Parser a err : Str -> Result (a, Str) err

Maybe a : [Some a, None]

## PARSERS --------------------------------------------------------------------

## Create a parser that will match a specific string
string : Str -> Parser Str [StringNotFound]
string = |prefix|
    |str|
        if Str.starts_with(str, prefix) then
            Ok((prefix, Str.drop_prefix(str, prefix)))
        else
            Err StringNotFound

expect string("{")("{") == Ok(("{", ""))
expect string("Hello")("Hello, world!") == Ok(("Hello", ", world!"))

## Match a string of one or more consecutive whitespace characters
whitespace : Parser Str [WhitespaceNotFound]
whitespace = |str|
    parser = one_or_more(char |> filter(|c| List.contains([' ', '\t', '\n', '\r'], c))) |> map(|chars| Str.from_utf8(chars))
    parser(str) |> Result.map_err(|_| WhitespaceNotFound)

expect whitespace(" \t\n\r") == Ok((" \t\n\r", ""))
expect whitespace("Hello, world!") == Err(WhitespaceNotFound)

## Parse a single character
char : Parser U8 [CharNotFound]
char = |str|
    when Str.to_utf8(str) is
        [c, .. as rest] -> Ok((c, Str.from_utf8_lossy(rest)))
        [] -> Err CharNotFound

expect char("1") == Ok(('1', ""))

## Parse a non-clustered grapheme
atomic_grapheme : Parser Str [GraphemeNotFound]
atomic_grapheme = |str|
    when Str.to_utf8(str) |> CodePoint.parse_partial_utf8 is
        Ok({code_point}) -> 
            cp_str = CodePoint.to_str([code_point]) ?  |_| GraphemeNotFound
            rest = Str.drop_prefix(str, cp_str)
            Ok((cp_str, rest))
        Err _ -> Err GraphemeNotFound

expect
    res = atomic_grapheme("🔥")
    res == Ok(("🔥", ""))

## Parse a digit (converts from ASCII value to integer)
digit : Parser U8 [NotADigit]
digit = |str| 
    parser = char |> filter(|c| is_digit(c)) |> map(|c| Ok(c - '0'))
    parser(str) |> Result.map_err(|_| NotADigit)

expect digit("1") == Ok((1, ""))

## Parse an integer
integer : Parser U64 [NotAnInteger]
integer = |str|
    parser = one_or_more(char |> filter(|c| is_digit(c))) |> map(|digits| digits |> Str.from_utf8_lossy |> Str.to_u64)
    parser(str) |> Result.map_err(|_| NotAnInteger)

expect integer("1") == Ok((1, ""))
expect integer("012345") == Ok((12345, ""))

## Parse a floating point number
float : Parser F64 [NotAFloat]
float = |str|
    parser = integer |> both(maybe(string(".") |> rhs(integer))) |> map(|(l, maybe_r)|
        when maybe_r is
            None -> Ok(Num.to_f64(l))
            Some(r) -> Ok(int_pair_to_float(l, r))
    )
    parser(str) |> Result.map_err(|_| NotAFloat)

expect
    import Unsafe
    f = float("123.456789") |> finalize_lazy |> Unsafe.unwrap("Failed to parse float")
    approx_eq(f, 123.456789)

expect
    import Unsafe
    f = float("123") |> finalize_lazy |> Unsafe.unwrap("Failed to parse float")
    approx_eq(f, 123)

## PARSER COMBINATORS ---------------------------------------------------------

## Create a parser that will filter out matches that do not satisfy the given predicate
filter : Parser a _, (a -> Bool) -> Parser a [FilteredOut]
filter = |parser, predicate|
    map(parser, |match| if predicate(match) then Ok(match) else Err FilteredOut)

expect
    parser = filter(char, |c| c == 'a')
    parser("a") |> finalize_lazy == Ok('a')

expect
    parser = filter(char, |c| c == 'a')
    parser("b") == Err(FilteredOut)

## Create a parser that will exclude matches that satisfy the given predicate
excluding : Parser a _, (a -> Bool) -> Parser a [Excluded]_
excluding = |parser, predicate|
    map(parser, |match| if predicate(match) then Err Excluded else Ok(match))

expect
    parser = excluding(char, |c| c == 'a')
    parser("a") == Err(Excluded)

expect
    parser = excluding(char, |c| c == 'a')
    parser("b") |> finalize_lazy == Ok('b')

## Convert a parser of one type into a parser of another type using a tranform function which turns the first type into a result of the second type
map : Parser a _, (a -> Result b _) -> Parser b _
map = |parser, transform|
    flat_map(
        parser,
        |match|
            |str|
                when transform(match) is
                    Ok(b) -> Ok((b, str))
                    Err err -> Err err,
    )

expect
    parser = map(char, |c| Str.from_utf8([c]))
    parser("a") |> finalize_lazy == Ok("a")

## Convert a parser of one type into a parser of another type using a transform function which turns the first type into a parser of the second type
flat_map : Parser a _, (a -> Parser b _) -> Parser b _
flat_map = |parser_a, transform|
    |str|
        when parser_a(str) is
            Ok((a, rest)) -> transform(a)(rest)
            Err err -> Err err

expect
    parser = flat_map(char, |c| |str| if c == '1' then Ok(("One", str)) else Err(NotOne))
    parser("1") |> finalize_lazy == Ok("One")

## Create a parser which matches one or more occurrences of the given parser
one_or_more : Parser a _ -> Parser (List a) [LessThanOneFound]_
one_or_more = |parser|
    map(
        zero_or_more(parser),
        |list|
            if List.is_empty(list) then
                Err LessThanOneFound
            else
                Ok(list),
    )

expect
    parser = one_or_more(char)
    parser("abc") |> finalize_lazy == Ok(['a', 'b', 'c'])

expect
    parser = one_or_more(char)
    parser("") |> finalize_lazy == Err(LessThanOneFound)

## Create a parser which matches zero or more occurrences of the given parser
zero_or_more : Parser a _ -> Parser (List a) _
zero_or_more = |parser|
    |str|
        helper = |acc, current_str|
            when parser(current_str) is
                Ok((match, rest)) -> helper (List.append acc match) rest
                Err _ -> Ok((acc, current_str))
        helper [] str

expect
    parser = zero_or_more(char)
    parser("abc") |> finalize_lazy == Ok(['a', 'b', 'c'])

expect
    parser = zero_or_more(char)
    parser("") |> finalize_lazy == Ok([])

## Combine 2 parsers into a single parser that returns a tuple of 2 values
zip : Parser a _, Parser b _ -> Parser (a, b) _
zip = |parser_a, parser_b|
    flat_map(parser_a, |match_a| map(parser_b, |match_b| Ok((match_a, match_b))))

## Combine 3 parsers into a single parser that returns a tuple of 3 values
zip_3 : Parser a _, Parser b _, Parser c _ -> Parser (a, b, c) _
zip_3 = |parser_a, parser_b, parser_c|
    zip(parser_a, zip(parser_b, parser_c)) |> map(|(a, (b, c))| Ok((a, b, c)))

## Combine 4 parsers into a single parser that returns a tuple of 4 values
zip_4 : Parser a _, Parser b _, Parser c _, Parser d _ -> Parser (a, b, c, d) _
zip_4 = |parser_a, parser_b, parser_c, parser_d|
    zip(parser_a, zip_3(parser_b, parser_c, parser_d)) |> map(|(a, (b, c, d))| Ok((a, b, c, d)))

## Combine 5 parsers into a single parser that returns a tuple of 5 values
zip_5 : Parser a _, Parser b _, Parser c _, Parser d _, Parser e _ -> Parser (a, b, c, d, e) _
zip_5 = |parser_a, parser_b, parser_c, parser_d, parser_e|
    zip(parser_a, zip_4(parser_b, parser_c, parser_d, parser_e)) |> map(|(a, (b, c, d, e))| Ok((a, b, c, d, e)))

zip_6 : Parser a _, Parser b _, Parser c _, Parser d _, Parser e _, Parser f _ -> Parser (a, b, c, d, e, f) _
zip_6 = |parser_a, parser_b, parser_c, parser_d, parser_e, parser_f|
    zip(parser_a, zip_5(parser_b, parser_c, parser_d, parser_e, parser_f)) |> map(|(a, (b, c, d, e, f))| Ok((a, b, c, d, e, f)))

expect
    parser = zip_6(digit, digit, digit, digit, digit, digit)
    parser("123456") |> finalize_lazy == Ok((1, 2, 3, 4, 5, 6))

## Convert a parser that can fail into a parser that can return a Maybe
maybe : Parser a _ -> Parser (Maybe a) _
maybe = |parser|
    |str|
        when parser(str) is
            Ok((match, rest)) -> Ok((Some(match), rest))
            Err _ -> Ok((None, str))

## Try the first parser, if it fails, try the second parser
or_else : Parser a err, Parser a err -> Parser a err
or_else = |parser_a, parser_b|
    |str|
        when parser_a(str) is
            Ok(result) -> Ok(result)
            Err _ -> parser_b(str)

expect
    parser = or_else(string("abc"), string("def"))
    parser("abc") == Ok(("abc", ""))

expect
    parser = or_else(string("abc"), string("def"))
    parser("def") == Ok(("def", ""))    

## Try each parser in sequence until one succeeds
one_of : List (Parser a err) -> Parser a [NoMatchFound]
one_of = |parsers|
    |str|
        List.walk_until(
            parsers,
            Err(NoMatchFound),
            |none, parser|
                when parser(str) is
                    Ok(result) -> Break(Ok(result))
                    Err _ -> Continue(none),
        )

expect
    parser = one_of([string("abc"), string("def")])
    parser("abc") == Ok(("abc", ""))

expect
    parser = one_of([string("abc"), string("def")])
    parser("def") == Ok(("def", ""))

expect
    parser = one_of([string("abc"), string("def")])
    parser("ghi") == Err(NoMatchFound)

## OPERATORS ------------------------------------------------------------------

## keep the result of the left parser
lhs : Parser a _, Parser b _ -> Parser a _
lhs = |parser_l, parser_r|
    zip(parser_l, parser_r) |> map(|(l, _r)| Ok(l))

expect
    parser = string("l") |> lhs(string("r"))
    parser("lr") == Ok(("l", ""))

## keep the result of the right parser
rhs : Parser a _, Parser b _ -> Parser b _
rhs = |parser_l, parser_r|
    zip(parser_l, parser_r) |> map(|(_l, r)| Ok(r))

expect
    parser = string("l") |> rhs(string("r"))
    parser("lr") == Ok(("r", ""))

expect
    parser = string("{") |> rhs(integer) |> lhs(string("}"))
    parser("{123}") == Ok((123, ""))

## keep the result of both parsers
both : Parser a _, Parser b _ -> Parser (a, b) _
both = |parser_l, parser_r| zip(parser_l, parser_r)

expect
    parser = string("{") |> both(string("}"))
    parser("{}") == Ok (("{", "}"), "")

## Finalization ---------------------------------------------------------------

## Finalize a parser result only if the Str has been fully consumed
finalize : Result (a, Str) _ -> Result a [NotConsumed]_
finalize = |result|
    when result is
        Ok((a, "")) -> Ok(a)
        Ok(_) -> Err(NotConsumed)
        Err err -> Err err

expect
    parser = string("Hello")
    parser("Hello") |> finalize == Ok("Hello")

expect
    parser = string("Hello")
    parser("Hello, world!") |> finalize == Err(NotConsumed)

## Finalize a parser result without consuming the remaining Str
finalize_lazy : Result (a, Str) err -> Result a err
finalize_lazy = |result| result |> Result.map_ok(.0)

expect
    parser = string("Hello")
    parser("Hello, world!") |> finalize_lazy == Ok("Hello")

expect 
    parser = string("world!")
    parser("Hello, world!") |> finalize_lazy == Err(StringNotFound)
