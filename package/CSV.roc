## This module contains parsers specifically for parsing csv files
module [comma, newline, csv_string]

import Parse exposing [Parser, char, string, rhs, lhs, map, one_or_more, excluding, filter, one_of, finalize, finalize_lazy]

## Match a comma character
comma : Parser U8 [CommaNotFound]
comma = |str|
    parser = char |> filter(|c| c == ',')
    parser(str) |> Result.map_err(|_| CommaNotFound)

expect comma(",") |> finalize == Ok(',')

## Match a newline character
newline : Parser U8 [NewlineNotFound]
newline = |str|
    parser = char |> filter(|c| c == '\n')
    parser(str) |> Result.map_err(|_| NewlineNotFound)

expect newline("\n") |> finalize == Ok('\n')

## Match a string with or without quotation marks
csv_string : Parser Str [InvalidString]
csv_string = |str|
    parser = one_of([quoted_string, unquoted_string])
    parser(str) |> Result.map_err(|_| InvalidString)

expect csv_string("\"Hello, world!\"") |> finalize == Ok("Hello, world!")
expect csv_string("Hello, world!") |> finalize_lazy == Ok("Hello")

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
