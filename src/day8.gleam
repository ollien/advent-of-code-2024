import advent_of_code_2024
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleam/string

type Dimensions {
  Dimensions(height: Int, width: Int)
}

type Position {
  Position(row: Int, column: Int)
}

type Map {
  Map(dimensions: Dimensions, antennas: dict.Dict(String, List(Position)))
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use map <- result.try(parse_input(input))

  io.println("Part 1: " <> part1(map))
  Ok(Nil)
}

fn part1(map: Map) -> String {
  map
  |> locate_antinodes()
  |> set.size()
  |> int.to_string
}

fn locate_antinodes(map: Map) -> set.Set(Position) {
  map.antennas
  |> dict.values()
  |> list.flat_map(list.combination_pairs)
  |> list.flat_map(fn(antenna_pair) {
    let #(antenna1, antenna2) = antenna_pair
    let row_distance = antenna1.row - antenna2.row
    let column_distance = antenna1.column - antenna2.column

    [
      Position(
        row: antenna1.row + row_distance,
        column: antenna1.column + column_distance,
      ),
      Position(
        row: antenna2.row - row_distance,
        column: antenna2.column - column_distance,
      ),
    ]
  })
  |> list.filter(fn(position) {
    position.column < map.dimensions.width
    && position.row < map.dimensions.height
    && position.column >= 0
    && position.row >= 0
  })
  |> set.from_list()
}

fn parse_input(input: String) -> Result(Map, String) {
  let input_lines =
    input
    |> string.trim_end()
    |> string.split("\n")

  use dimensions <- result.try(measure_input(input_lines))
  let antennas = parse_antenna_locations(input_lines)

  Ok(Map(dimensions:, antennas:))
}

fn parse_antenna_locations(
  input_lines: List(String),
) -> dict.Dict(String, List(Position)) {
  list.index_fold(
    over: input_lines,
    from: dict.new(),
    with: fn(antennas, line, row) {
      list.index_fold(
        over: string.to_graphemes(line),
        from: antennas,
        with: fn(antennas, char, column) {
          case char {
            "." -> antennas
            char ->
              dict.upsert(antennas, char, fn(maybe_entires) {
                maybe_entires
                |> option.map(fn(entries) {
                  [Position(row:, column:), ..entries]
                })
                |> option.unwrap(or: [Position(row:, column:)])
              })
          }
        },
      )
    },
  )
}

fn measure_input(input_lines: List(String)) -> Result(Dimensions, String) {
  use first_line, rest_lines <- pop_or(
    input_lines,
    or: Ok(Dimensions(height: 0, width: 0)),
  )

  let height = list.length(input_lines)
  let width = string.length(first_line)
  case list.all(rest_lines, fn(line) { string.length(line) == width }) {
    True -> Ok(Dimensions(height:, width:))
    False -> Error("Input must be rectangular")
  }
}

fn pop_or(items: List(a), or or: b, then continue: fn(a, List(a)) -> b) -> b {
  case items {
    [] -> or
    [head, ..rest] -> {
      continue(head, rest)
    }
  }
}
