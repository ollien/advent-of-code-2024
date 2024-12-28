import advent_of_code_2024
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleam/string

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use input <- result.try(parse_input(input))

  io.println("Part 1: " <> part1(input))

  Ok(Nil)
}

fn part1(adjacencies: dict.Dict(String, set.Set(String))) -> String {
  adjacencies
  |> dict.to_list()
  |> list.flat_map(fn(pair) {
    let #(parent, children) = pair
    let all = children |> set.insert(parent) |> set.to_list()

    all
    |> list.combinations(3)
    |> list.filter(fn(combinations) {
      combinations
      |> list.combination_pairs()
      |> list.all(fn(pair) {
        adjacencies
        |> dict.get(pair.0)
        |> result.unwrap(or: set.new())
        |> set.contains(pair.1)
      })
    })
  })
  |> set.from_list()
  |> set_count(fn(triplet) {
    list.any(triplet, fn(computer) { string.starts_with(computer, "t") })
  })
  |> int.to_string()
}

fn set_count(set: set.Set(a), counter: fn(a) -> Bool) -> Int {
  set
  |> set.filter(counter)
  |> set.size()
}

fn parse_input(
  input: String,
) -> Result(dict.Dict(String, set.Set(String)), String) {
  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_map(parse_input_line)
  |> result.map(build_adjacencies)
}

fn build_adjacencies(
  pairs: List(#(String, String)),
) -> dict.Dict(String, set.Set(String)) {
  case pairs {
    [] -> dict.new()
    [#(left, right), ..rest] -> {
      build_adjacencies(rest)
      |> dict.upsert(left, fn(existing) {
        existing
        |> option.unwrap(or: set.new())
        |> set.insert(right)
      })
      |> dict.upsert(right, fn(existing) {
        existing
        |> option.unwrap(or: set.new())
        |> set.insert(left)
      })
    }
  }
}

fn parse_input_line(line: String) -> Result(#(String, String), String) {
  case string.split(line, "-") {
    [left, right] -> Ok(#(left, right))
    _ -> Error("Malformed input line, must have exactly two pairs " <> line)
  }
}
