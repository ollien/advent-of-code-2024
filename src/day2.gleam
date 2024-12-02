import advent_of_code_2024
import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/yielder

type Report {
  Report(levels: List(Int))
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(raw_input: String) -> Result(Nil, String) {
  use parsed_input <- result.try(parse_input(raw_input))

  io.println("Part 1: " <> part1(parsed_input))
  io.println("Part 2: " <> part2(parsed_input))
  Ok(Nil)
}

fn part1(input: List(Report)) -> String {
  input
  |> list.count(is_report_safe)
  |> int.to_string()
}

fn part2(input: List(Report)) -> String {
  input
  |> list.count(can_report_be_made_safe)
  |> int.to_string()
}

fn is_report_safe(report: Report) -> Bool {
  case report {
    Report(levels: []) -> True
    Report(levels: [_one]) -> True
    Report(levels:) -> {
      let level_differences =
        levels
        |> list.window_by_2
        |> list.map(fn(pair) { pair.1 - pair.0 })

      let all_positive = list.all(level_differences, fn(n) { n > 0 })
      let all_negative = list.all(level_differences, fn(n) { n < 0 })
      let all_in_tolerance =
        list.all(level_differences, fn(n) {
          int.absolute_value(n) >= 1 && int.absolute_value(n) <= 3
        })

      { all_positive || all_negative } && all_in_tolerance
    }
  }
}

fn can_report_be_made_safe(report: Report) -> Bool {
  use <- bool.guard(when: is_report_safe(report), return: True)

  yielder.range(from: 0, to: list.length(report.levels) - 1)
  |> yielder.map(fn(index_to_drop) {
    Report(levels: drop_at(report.levels, index_to_drop))
  })
  |> yielder.any(is_report_safe)
}

// drops at the given index, if it is in bounds. Otherwise returns the list itself
fn drop_at(list: List(a), idx: Int) -> List(a) {
  let length = list.length(list)
  use <- bool.guard(when: length <= 1 && idx <= 1, return: [])
  use <- bool.guard(when: length <= 1, return: list)

  case list.split(list, idx) {
    #(half1, []) -> half1
    #(half1, [_drop, ..half2]) -> {
      list.flatten([half1, half2])
    }
  }
}

fn parse_input(input: String) -> Result(List(Report), String) {
  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_map(parse_line)
}

fn parse_line(input_line: String) -> Result(Report, String) {
  input_line
  |> string.split(" ")
  |> list.try_map(parse_int)
  |> result.map(fn(report_levels) { Report(levels: report_levels) })
}

fn parse_int(data: String) -> Result(Int, String) {
  data
  |> int.parse()
  |> result.map_error(fn(_nil) { "Invalid integer '" <> data <> "'" })
}
