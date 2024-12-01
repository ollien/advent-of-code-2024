import advent_of_code_2024
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string

type LocationID =
  Int

type LocationPair {
  LocationPair(left: LocationID, right: LocationID)
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(file: String) -> Result(Nil, String) {
  use parsed_input <- result.try(parse(file))

  io.println(part1(parsed_input))
  io.println(part2(parsed_input))

  Ok(Nil)
}

fn part1(input: List(LocationPair)) -> String {
  let lefts =
    input
    |> list.map(fn(pair) { pair.left })
    |> list.sort(by: int.compare)

  let rights =
    input
    |> list.map(fn(pair) { pair.right })
    |> list.sort(by: int.compare)

  list.zip(lefts, rights)
  |> list.map(fn(pair) { int.absolute_value(pair.1 - pair.0) })
  |> int.sum()
  |> int.to_string()
}

fn part2(input: List(LocationPair)) -> String {
  let lefts = list.map(input, fn(pair) { pair.left })
  let rights = list.map(input, fn(pair) { pair.right })
  let right_counts = count(rights)

  lefts
  |> list.map(fn(num) {
    right_counts
    |> dict.get(num)
    |> result.map(fn(count) { num * count })
    |> result.unwrap(or: 0)
  })
  |> int.sum()
  |> int.to_string()
}

fn parse(file: String) -> Result(List(LocationPair), String) {
  file
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_map(parse_line)
}

fn parse_line(line: String) -> Result(LocationPair, String) {
  line
  |> string.split("   ")
  |> list.try_map(parse_number)
  |> result.then(list_to_location_pair)
}

fn parse_number(n: String) -> Result(Int, String) {
  n
  |> int.parse()
  |> result.map_error(fn(_nil) { "Invalid integer " <> n })
}

fn list_to_location_pair(items: List(Int)) -> Result(LocationPair, String) {
  case items {
    [left, right] -> Ok(LocationPair(left:, right:))
    _ ->
      Error(
        "Cannot decode list of length "
        <> int.to_string(list.length(items))
        <> " as a LocationPair",
      )
  }
}

fn count(haystack: List(a)) -> dict.Dict(a, Int) {
  list.fold(haystack, from: dict.new(), with: fn(counts, item) {
    dict.upsert(counts, item, fn(existing_count) {
      existing_count
      |> option.map(fn(count) { count + 1 })
      |> option.unwrap(or: 1)
    })
  })
}
