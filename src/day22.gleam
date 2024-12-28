import advent_of_code_2024
import bravo
import bravo/uset
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/task
import gleam/result
import gleam/set
import gleam/string

type Quad =
  #(Int, Int, Int, Int)

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use numbers <- result.try(parse_input(input))

  io.println("Part 1: " <> part1(numbers))
  io.println("Part 2: " <> part2(numbers))
  Ok(Nil)
}

fn part1(numbers: List(Int)) -> String {
  numbers
  |> list.map(fn(number) { nth_number(number, 2000) })
  |> int.sum()
  |> int.to_string()
}

fn part2(numbers: List(Int)) -> String {
  let window_prices =
    numbers
    |> list.map(fn(number) {
      let assert Ok(table) =
        uset.new("part2-" <> int.to_string(number), 1, bravo.Public)

      task.async(fn() { delta_windows_to_prices(table, number) })
    })
    |> list.map(task.await_forever)

  let all_windows =
    window_prices
    |> list.flat_map(fn(table) {
      table
      |> uset.tab2list()
      |> list.map(fn(entry) { entry.0 })
    })
    |> set.from_list()

  all_windows
  |> set.to_list()
  |> list.map(fn(window) {
    task.async(fn() {
      window_prices
      |> list.map(fn(prices) {
        prices
        |> uset.lookup(window)
        |> result.map(fn(entry) { entry.1 })
        |> result.unwrap(or: 0)
      })
      |> int.sum()
    })
  })
  |> list.map(task.await_forever)
  |> list.reduce(int.max)
  |> result.map(int.to_string)
  |> result.unwrap(or: "No solution found")
}

fn delta_windows_to_prices(
  table: uset.USet(#(Quad, Int)),
  number: Int,
) -> uset.USet(#(Quad, Int)) {
  let prices =
    number
    |> n_numbers(2000)
    |> list.map(fn(n) { n % 10 })

  let entries =
    prices
    |> deltas()
    |> list.window(4)
    |> list.map(fn(list) {
      let assert [a, b, c, d] = list

      #(a, b, c, d)
    })
    |> list.zip(list.drop(prices, 4))
    // Must remove duplicate ranges in order to only react on the first seen sequence
    // We could use uset.insert_new, but in testing this is slower, and I assume it has
    // to do with the FFI overhead for an ETS insert
    |> keep_first_dupe_keys()

  uset.insert(table, entries)

  table
}

fn keep_first_dupe_keys(list: List(#(a, b))) {
  do_keep_first_dupe_keys(list, set.new(), [])
}

fn do_keep_first_dupe_keys(
  list: List(#(a, b)),
  seen: set.Set(a),
  acc: List(#(a, b)),
) {
  case list {
    [] -> acc
    [#(a, b), ..rest] -> {
      case set.contains(seen, a) {
        True -> do_keep_first_dupe_keys(rest, seen, acc)
        False ->
          do_keep_first_dupe_keys(rest, set.insert(seen, a), [#(a, b), ..acc])
      }
    }
  }
}

fn deltas(nums: List(Int)) -> List(Int) {
  case nums {
    [] | [_n] -> []
    nums -> {
      nums
      |> list.window_by_2()
      |> list.map(fn(pair) { pair.1 - pair.0 })
    }
  }
}

fn n_numbers(init num: Int, times n: Int) -> List(Int) {
  list.range(from: 0, to: n - 1)
  |> list.fold(from: [num], with: fn(acc, _nth) {
    let assert [head, ..] = acc
    [next_n(head), ..acc]
  })
  |> list.reverse()
}

fn nth_number(init num: Int, times n: Int) -> Int {
  list.fold(list.range(from: 0, to: n - 1), from: num, with: fn(acc, _nth) {
    next_n(acc)
  })
}

fn next_n(n: Int) -> Int {
  let n = n |> mix(n * 64) |> prune()
  let n = n |> mix(n / 32) |> prune()
  let n = n |> mix(n * 2048) |> prune()

  n
}

fn mix(a: Int, b: Int) -> Int {
  int.bitwise_exclusive_or(a, b)
}

fn prune(n: Int) -> Int {
  n % 16_777_216
}

fn parse_input(input: String) {
  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_map(parse_int)
}

fn parse_int(n: String) -> Result(Int, String) {
  case int.parse(n) {
    Ok(res) -> Ok(res)
    Error(Nil) -> Error("Invalid integer " <> n)
  }
}
