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

type ContinueSimulation(a) {
  ContinueSimulation
  StopSimulation(reason: a)
}

fn run(input: String) -> Result(Nil, String) {
  use map <- result.try(parse_map(input))
  io.println("Part 1: " <> part1(map))
  io.println("Part 2: " <> part2(map))
  Ok(Nil)
}

fn part1(map: Map) -> String {
  let #(visited, _stop_reason) =
    run_simulation(map, fn(map, _guard_positions) {
      case is_out_of_bounds(map, map.guard.position) {
        True -> StopSimulation(Nil)
        False -> ContinueSimulation
      }
    })

  visited
  |> set.map(fn(guard) { guard.position })
  |> set.size()
  |> int.to_string()
}

fn part2(map: Map) -> String {
  let #(original_guard_path, _stop_reason) =
    run_simulation(map, fn(map, _position) {
      case is_out_of_bounds(map, map.guard.position) {
        True -> StopSimulation(Nil)
        False -> ContinueSimulation
      }
    })

  let guard_starting_position = map.guard.position
  original_guard_path
  |> set.map(fn(guard) { guard.position })
  |> set.filter(fn(position) { position != guard_starting_position })
  |> set.to_list()
  |> list.filter(fn(position) {
    let #(_visited, is_loop) =
      run_simulation(
        Map(..map, obstacles: set.insert(map.obstacles, position)),
        fn(map, guard_states) {
          let is_out_of_bounds = is_out_of_bounds(map, map.guard.position)
          let is_loop = set.contains(guard_states, map.guard)

          use <- bool.guard(when: is_loop, return: StopSimulation(True))
          use <- bool.guard(
            when: is_out_of_bounds,
            return: StopSimulation(False),
          )

          ContinueSimulation
        },
      )

    is_loop
  })
  |> list.length()
  |> int.to_string()
}

fn run_simulation(
  map: Map,
  can_continue: fn(Map, set.Set(Guard)) -> ContinueSimulation(a),
) -> #(set.Set(Guard), a) {
  do_run_simulation(map, can_continue, set.new())
}

fn do_run_simulation(
  map: Map,
  can_continue: fn(Map, set.Set(Guard)) -> ContinueSimulation(a),
  guard_states: set.Set(Guard),
) -> #(set.Set(Guard), a) {
  use <- continue_simulation(can_continue(map, guard_states), guard_states)

  let guard_positions = set.insert(guard_states, map.guard)
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

      do_run_simulation(next_map, can_continue, guard_positions)
    }

    False -> {
      let next_map =
        Map(..map, guard: Guard(..guard, position: guard_position_candidate))

      do_run_simulation(next_map, can_continue, guard_positions)
    }
  }
}

fn continue_simulation(
  continue: ContinueSimulation(a),
  guard_states: set.Set(Guard),
  simulation: fn() -> #(set.Set(Guard), a),
) -> #(set.Set(Guard), a) {
  case continue {
    ContinueSimulation -> simulation()
    StopSimulation(reason) -> #(guard_states, reason)
  }
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
