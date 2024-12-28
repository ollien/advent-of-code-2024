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
  io.println("Part 2: " <> part2(input))

  Ok(Nil)
}

fn part1(adjacencies: dict.Dict(String, set.Set(String))) -> String {
  adjacencies
  |> cliques_of_size(size: 3)
  |> set_count(fn(triplet) {
    list.any(triplet, fn(computer) { string.starts_with(computer, "t") })
  })
  |> int.to_string()
}

fn part2(adjacencies: dict.Dict(String, set.Set(String))) -> String {
  let max_size_result =
    dict.values(adjacencies)
    |> list.map(fn(n) {
      // include the parent in the adjacency
      set.size(n) + 1
    })
    |> list.reduce(int.max)
    |> result.map_error(fn(_nil) { "No adjacencies to find solution for" })

  max_size_result
  |> result.then(fn(max_size) {
    // This could probably be done more effectively by actually just trying to build the biggest clique,
    // but for my input this is two steps, so I'm not really concerned.
    list.range(from: max_size, to: 2)
    |> list.find_map(fn(size) {
      let candidates = cliques_of_size(adjacencies, size:)
      case set.to_list(candidates) {
        [] -> Error(Nil)
        [clique, ..] -> {
          clique
          |> list.sort(string.compare)
          |> string.join(",")
          |> Ok()
        }
      }
    })
    |> result.map_error(fn(_nil) { "No solution found" })
  })
  |> result.unwrap_both()
}

fn cliques_of_size(
  adjacencies: dict.Dict(String, set.Set(String)),
  size size: Int,
) -> set.Set(List(String)) {
  adjacencies
  |> dict.to_list()
  |> list.flat_map(fn(pair) {
    let #(parent, children) = pair
    let all = children |> set.insert(parent) |> set.to_list()

    all
    |> list.combinations(size)
    |> list.filter(fn(combinations) { all_connected(adjacencies, combinations) })
  })
  |> list.map(fn(clique) { list.sort(clique, string.compare) })
  |> set.from_list()
}

fn all_connected(
  adjacencies: dict.Dict(String, set.Set(String)),
  computers: List(String),
) -> Bool {
  computers
  |> list.combination_pairs()
  |> list.all(fn(pair) {
    adjacencies
    |> dict.get(pair.0)
    |> result.unwrap(or: set.new())
    |> set.contains(pair.1)
  })
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
