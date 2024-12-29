import advent_of_code_2024
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

type Input {
  Input(locks: List(List(Int)), keys: List(List(Int)))
}

type InputChunk {
  Lock(List(Int))
  Key(List(Int))
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(raw_input: String) -> Result(Nil, String) {
  use input <- result.try(parse_input(raw_input))
  io.println("Part 1: " <> part1(input))
  io.println("Part 2: Merry Christmas :) ")

  Ok(Nil)
}

fn part1(input: Input) -> String {
  input.keys
  |> list.map(fn(key) {
    list.count(input.locks, fn(lock) {
      list.zip(key, lock)
      |> list.map(fn(pair) { pair.0 + pair.1 })
      |> list.all(fn(n) { n <= 5 })
    })
  })
  |> int.sum()
  |> int.to_string()
}

fn parse_input(input: String) -> Result(Input, String) {
  let chunks =
    input
    |> string.trim_end()
    |> string.split("\n\n")

  list.try_fold(chunks, from: Input(locks: [], keys: []), with: fn(acc, chunk) {
    case parse_chunk(chunk) {
      Ok(Key(heights)) -> Ok(Input(..acc, keys: [heights, ..acc.keys]))
      Ok(Lock(heights)) -> Ok(Input(..acc, locks: [heights, ..acc.locks]))
      Error(err) -> Error(err)
    }
  })
}

fn parse_chunk(chunk: String) -> Result(InputChunk, String) {
  let lines =
    chunk
    |> string.split("\n")
    |> list.map(string.to_graphemes)
    |> list.transpose()
  case string.starts_with(chunk, "#####"), string.ends_with(chunk, "#####") {
    True, False ->
      Ok(Key(
        lines
        |> list.map(fn(line) {
          { count_start(line, fn(chr) { chr == "#" }) - 1 }
        }),
      ))

    False, True -> {
      Ok(Lock(
        lines
        |> list.map(list.reverse)
        |> list.map(fn(line) {
          { count_start(line, fn(chr) { chr == "#" }) - 1 }
        }),
      ))
    }
    _, _ -> Error("Could not determine if value was key or lock")
  }
}

fn count_start(l: List(a), matches: fn(a) -> Bool) -> Int {
  case l {
    [] -> 0
    [head, ..rest] -> {
      case matches(head) {
        True -> 1 + count_start(rest, matches)
        False -> 0
      }
    }
  }
}
