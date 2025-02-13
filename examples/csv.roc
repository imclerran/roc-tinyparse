app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
    parse: "../package/main.roc",
}

import "packages.csv" as csv : Str

import cli.Stdout
import parse.Parse exposing [both, lhs, rhs, string, maybe, map, one_or_more, finalize]
import parse.CSV exposing [csv_string, comma, newline]

main! = |_|
    parse_csv(csv)?
    |> List.for_each_try!(
        |{ repo, alias, version }|
            Stdout.line!("repo: ${repo} | alias: ${alias} | version: ${version}"),
    )

parse_csv : Str -> Result (List { alias : Str, repo : Str, version: Str }) [InvalidCSV]
parse_csv = |csv_text|
    parser = maybe(parse_csv_header) |> rhs(one_or_more(parse_csv_line))
    parser(csv_text) |> finalize |> Result.map_err(|_| InvalidCSV) 

parse_csv_header = |str|
    parser = string("repo,alias,version") |> lhs(maybe(comma)) |> lhs(newline)
    parser(str) |> Result.map_err(|_| InvalidCSVHeader)

parse_csv_line = |str|
    parser =
        csv_string # first column
        |> lhs(comma) # keep first column, discard the comma
        |> both(csv_string) # keep the first and second column
        |> lhs(comma) # keep the first and second column, discard the comma
        |> both(csv_string) # keep the (first, second), and third column
        |> lhs(maybe(comma)) # discard the optional comma at the end of the line
        |> lhs(maybe(newline)) # discard the newline, which is optional at the end of the file
        |> map(|((repo, alias), version)| Ok({ repo, alias, version })) 
    parser(str) |> Result.map_err(|_| InvalidCSVLine)
