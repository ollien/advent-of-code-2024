import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/set
import gleam/string

type Position {
  Position(row: Int, col: Int)
}

type Dimensions {
  Dimensions(height: Int, width: Int)
}

type Map {
  Map(locations: dict.Dict(Position, Int), dimensions: Dimensions)
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use #(map, trailheads) <- result.try(parse_input(input))
  use part1_result <- result.try(part1(map, trailheads))

  io.println("Part 1: " <> part1_result)
  Ok(Nil)
}

fn part1(map: Map, trailheads: List(Position)) -> Result(String, String) {
  use scores <- result.map(
    list.try_map(trailheads, fn(trailhead) { trail_score(map, trailhead) }),
  )
  scores
  |> int.sum()
  |> int.to_string()
}

fn trail_score(map: Map, trailhead: Position) -> Result(Int, String) {
  let trailhead_result =
    map.locations
    |> dict.get(trailhead)
    |> result.map_error(fn(_nil) { "Unknown trail start" })
    |> result.then(fn(height) {
      case height {
        0 -> Ok(Nil)
        _ -> Error("Trails must start at zero")
      }
    })

  use _ <- result.map(trailhead_result)
  do_trail_score(map, [trailhead], set.new(), 0)
}

fn do_trail_score(
  map: Map,
  to_visit: List(Position),
  visited: set.Set(Position),
  acc: Int,
) -> Int {
  use visiting, to_visit <- try_pop(to_visit, or: acc)
  use <- bool.lazy_guard(when: set.contains(visited, visiting), return: fn() {
    do_trail_score(map, to_visit, visited, acc)
  })

  // We should not be passing invalid positions in to_visit
  let assert Ok(visiting_height) = dict.get(map.locations, visiting)
  let visited = set.insert(visited, visiting)
  case visiting_height {
    9 -> do_trail_score(map, to_visit, visited, acc + 1)
    _ -> {
      let neighbors_to_visit =
        visiting
        |> neighbors()
        |> list.filter_map(fn(neighbor) {
          use height <- result.try(dict.get(map.locations, neighbor))
          use <- bool.guard(
            when: height != visiting_height + 1,
            return: Error(Nil),
          )

          Ok(neighbor)
        })

      do_trail_score(
        map,
        list.flatten([neighbors_to_visit, to_visit]),
        visited,
        acc,
      )
    }
  }
}

fn neighbors(position: Position) -> List(Position) {
  [
    Position(..position, row: position.row - 1),
    Position(..position, row: position.row + 1),
    Position(..position, col: position.col + 1),
    Position(..position, col: position.col - 1),
  ]
}

fn parse_input(input: String) -> Result(#(Map, List(Position)), String) {
  let input_lines =
    input
    |> string.trim_end()
    |> string.split("\n")

  use dimensions <- result.try(measure_input(input_lines))
  use locations <- result.try(parse_grid(input_lines))
  let trailheads =
    locations
    |> dict.to_list()
    |> list.filter_map(fn(entry) {
      let #(position, n) = entry
      case n {
        0 -> Ok(position)
        _ -> Error(Nil)
      }
    })

  Ok(#(Map(dimensions:, locations:), trailheads))
}

fn parse_grid(
  input_lines: List(String),
) -> Result(dict.Dict(Position, Int), String) {
  let line_parse_result =
    input_lines
    |> list.index_map(parse_grid_line)
    |> result.all()

  use lines <- result.map(line_parse_result)

  list.fold(lines, from: dict.new(), with: dict.merge)
}

fn parse_grid_line(
  line: String,
  row: Int,
) -> Result(dict.Dict(Position, Int), String) {
  line
  |> string.to_graphemes
  |> list.index_map(fn(value, col) { #(Position(row:, col:), value) })
  |> list.filter(fn(entry) {
    let #(_position, value) = entry

    value != "."
  })
  |> list.try_map(fn(entry) {
    let #(position, value) = entry
    use parsed_value <- result.try(parse_int(value))
    Ok(#(position, parsed_value))
  })
  |> result.map(dict.from_list)
}

fn measure_input(input_lines: List(String)) -> Result(Dimensions, String) {
  let height = list.length(input_lines)
  use head_row, rest_rows <- try_pop(
    input_lines,
    or: Ok(Dimensions(height: 0, width: 0)),
  )

  let width = string.length(head_row)
  case list.all(rest_rows, fn(row) { string.length(row) == width }) {
    True -> Ok(Dimensions(height:, width:))
    False -> Error("Input must be rectangular")
  }
}

fn parse_int(s: String) -> Result(Int, String) {
  s
  |> int.parse()
  |> result.map_error(fn(_nil) { "Invalid int " <> s })
}

fn try_pop(l: List(a), or or: b, continue continue: fn(a, List(a)) -> b) -> b {
  case l {
    [] -> or
    [head, ..rest] -> continue(head, rest)
  }
}
