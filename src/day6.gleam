import advent_of_code_2024
import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/set
import gleam/string

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

type Dimensions {
  Dimensions(width: Int, height: Int)
}

type Direction {
  Up
  Right
  Down
  Left
}

type Position {
  Position(row: Int, col: Int)
}

type Guard {
  Guard(position: Position, direction: Direction)
}

type Map {
  Map(dimensions: Dimensions, obstacles: set.Set(Position), guard: Guard)
}

fn run(input: String) -> Result(Nil, String) {
  use map <- result.try(parse_map(input))
  io.println("Part 1: " <> part1(map))
  Ok(Nil)
}

fn part1(map: Map) -> String {
  map
  |> run_simulation()
  |> set.size()
  |> int.to_string()
}

fn run_simulation(map: Map) -> set.Set(Position) {
  do_run_simulation(map, set.new())
}

fn do_run_simulation(
  map: Map,
  guard_positions: set.Set(Position),
) -> set.Set(Position) {
  use <- bool.guard(
    when: is_out_of_bounds(map, map.guard.position)
      && !set.is_empty(guard_positions),
    return: guard_positions,
  )

  let guard_positions = set.insert(guard_positions, map.guard.position)
  let guard = map.guard
  let guard_position_candidate =
    move_in_direction(guard.position, guard.direction)

  case set.contains(map.obstacles, guard_position_candidate) {
    True -> {
      let next_map =
        Map(
          ..map,
          guard: Guard(..guard, direction: rotate_90deg(guard.direction)),
        )
      do_run_simulation(next_map, guard_positions)
    }

    False -> {
      let next_map =
        Map(..map, guard: Guard(..guard, position: guard_position_candidate))
      do_run_simulation(next_map, guard_positions)
    }
  }
}

fn debug_map(map: Map) {
  list.range(from: 0, to: map.dimensions.width - 1)
  |> list.each(fn(row) {
    list.range(from: 0, to: map.dimensions.width - 1)
    |> list.each(fn(col) {
      let position = Position(row:, col:)
      debug_guard(map, position)
      debug_obstacle(map, position)
      debug_empty_space(map, position)
    })
    io.print("\n")
  })
}

fn debug_guard(map: Map, cursor: Position) {
  use <- bool.guard(when: map.guard.position != cursor, return: Nil)

  case map.guard.direction {
    Up -> io.print("^")
    Down -> io.print("v")
    Left -> io.print("<")
    Right -> io.print(">")
  }
}

fn debug_obstacle(map: Map, cursor: Position) {
  use <- bool.guard(when: map.guard.position == cursor, return: Nil)
  use <- bool.guard(when: !set.contains(map.obstacles, cursor), return: Nil)
  io.print("#")
}

fn debug_empty_space(map: Map, cursor: Position) {
  use <- bool.guard(when: set.contains(map.obstacles, cursor), return: Nil)
  use <- bool.guard(when: map.guard.position == cursor, return: Nil)
  io.print(".")
}

fn is_out_of_bounds(map: Map, guard_position: Position) -> Bool {
  guard_position.row >= map.dimensions.height
  || guard_position.col >= map.dimensions.width
  || guard_position.col < 0
  || guard_position.row < 0
}

fn move_in_direction(position: Position, direction: Direction) -> Position {
  let Position(row:, col:) = position

  case direction {
    Up -> Position(..position, row: row - 1)
    Down -> Position(..position, row: row + 1)
    Right -> Position(..position, col: col + 1)
    Left -> Position(..position, col: col - 1)
  }
}

fn rotate_90deg(direction: Direction) -> Direction {
  case direction {
    Up -> Right
    Right -> Down
    Down -> Left
    Left -> Up
  }
}

fn parse_map(input: String) -> Result(Map, String) {
  let input_lines =
    input
    |> string.trim_end()
    |> string.split("\n")

  use dimensions <- result.try(input_dimensions(input_lines))
  use #(obstacles, guard_position) <- result.try(
    parse_obstacles_and_guard_position(input_lines),
  )

  let guard = Guard(position: guard_position, direction: Up)
  Ok(Map(dimensions:, obstacles:, guard:))
}

fn input_dimensions(input_lines: List(String)) -> Result(Dimensions, String) {
  use <- bool.guard(
    when: list.is_empty(input_lines),
    return: Ok(Dimensions(width: 0, height: 0)),
  )

  let assert [first_width, ..rest_widths] = list.map(input_lines, string.length)
  case list.all(rest_widths, fn(width) { width == first_width }) {
    True -> Ok(Dimensions(width: first_width, height: list.length(input_lines)))
    False -> Error("Input must be rectangular")
  }
}

fn parse_obstacles_and_guard_position(
  input_lines: List(String),
) -> Result(#(set.Set(Position), Position), String) {
  let #(obstacles, maybe_guard) =
    list.index_fold(
      input_lines,
      from: #(set.new(), Error("No guard found")),
      with: fn(acc, line, row) {
        list.index_fold(
          string.to_graphemes(line),
          from: acc,
          with: fn(acc, char, col) {
            let #(obstacles, maybe_guard) = acc
            let have_guard = result.is_ok(maybe_guard)

            case char {
              "#" -> #(set.insert(obstacles, Position(row:, col:)), maybe_guard)
              "^" if have_guard -> #(
                obstacles,
                Error("Cannot have more than one guard"),
              )
              "^" -> #(obstacles, Ok(Position(row:, col:)))
              _ -> acc
            }
          },
        )
      },
    )

  case maybe_guard {
    Error(err) -> Error(err)
    Ok(guard) -> Ok(#(obstacles, guard))
  }
}
