import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

type Position {
  Position(row: Int, col: Int)
}

type Dimensions {
  Dimensions(height: Int, width: Int)
}

type Map {
  Map(
    dimensions: Dimensions,
    obstacles: dict.Dict(Position, Obstacle),
    robot: Position,
  )
}

type Obstacle {
  Box
  Wall
}

type Direction {
  Up
  Down
  Left
  Right
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use #(map, directions) <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(map, directions))
  Ok(Nil)
}

fn part1(map: Map, directions: List(Direction)) -> String {
  let upd_map = simulate(map, directions)

  upd_map.obstacles
  |> dict.filter(fn(_position, obstacle) { obstacle == Box })
  |> dict.keys()
  |> list.map(fn(position) { position.row * 100 + position.col })
  |> int.sum()
  |> int.to_string()
}

fn print_map(map: Map) -> Nil {
  list.each(list.range(from: 0, to: map.dimensions.height - 1), fn(row) {
    list.each(list.range(from: 0, to: map.dimensions.width - 1), fn(col) {
      let position = Position(row:, col:)
      use <- bool.lazy_guard(map.robot == position, fn() { io.print("@") })

      case dict.get(map.obstacles, position) {
        Ok(Box) -> io.print("O")
        Ok(Wall) -> io.print("#")
        Error(Nil) -> io.print(".")
      }
    })
    io.print("\n")
  })
}

fn simulate(map: Map, directions: List(Direction)) -> Map {
  use direction, directions <- pop_or(directions, or: map)
  // print_map(map)
  let robot_candidate = move_in_direction(map.robot, direction)
  let map = case dict.get(map.obstacles, robot_candidate) {
    Ok(Wall) -> map
    Ok(Box) -> {
      try_move_box(map, robot_candidate, direction)
      |> result.map(fn(map) { Map(..map, robot: robot_candidate) })
      |> result.unwrap(or: map)
    }
    Error(Nil) -> Map(..map, robot: robot_candidate)
  }

  simulate(map, directions)
}

fn try_move_box(
  map: Map,
  box_location: Position,
  direction: Direction,
) -> Result(Map, Nil) {
  case do_try_move_box(map, box_location, direction) {
    Ok(map) -> {
      Ok(
        // remove the original box, we've spawned a new one at the end
        Map(..map, obstacles: dict.delete(map.obstacles, box_location)),
      )
    }
    Error(Nil) -> Error(Nil)
  }
}

fn do_try_move_box(
  map: Map,
  box_location: Position,
  direction: Direction,
) -> Result(Map, Nil) {
  let position_candidate = move_in_direction(box_location, direction)
  case dict.get(map.obstacles, position_candidate) {
    Ok(Box) -> {
      // io.println("--")
      // io.println(string.inspect(#("move box", position_candidate, direction)))
      // print_map(map)
      // io.println("--")
      do_try_move_box(map, position_candidate, direction)
    }

    Ok(Wall) -> Error(Nil)

    Error(Nil) -> {
      Ok(
        Map(
          ..map,
          obstacles: dict.insert(map.obstacles, position_candidate, Box),
        ),
      )
    }
  }
}

fn move_in_direction(position: Position, direction: Direction) -> Position {
  case direction {
    Up -> Position(..position, row: position.row - 1)
    Down -> Position(..position, row: position.row + 1)
    Left -> Position(..position, col: position.col - 1)
    Right -> Position(..position, col: position.col + 1)
  }
}

fn parse_input(input: String) -> Result(#(Map, List(Direction)), String) {
  let input_components =
    input
    |> string.trim_end()
    |> string.split("\n\n")

  case input_components {
    [raw_map, raw_directions] -> {
      use map <- result.try(parse_map(raw_map))
      use directions <- result.try(parse_directions(raw_directions))

      Ok(#(map, directions))
    }

    _ -> Error("input must have exactly two sections")
  }
}

fn parse_map(input: String) -> Result(Map, String) {
  let input_lines = string.split(input, "\n")
  use dimensions <- result.try(measure_input(input_lines))

  let #(obstacles, robots, unknown) =
    list.index_fold(
      input_lines,
      from: #(dict.new(), [], []),
      with: fn(acc, line, row) {
        list.index_fold(
          string.to_graphemes(line),
          from: acc,
          with: fn(acc, char, col) {
            let #(obstacles, robots, unknown) = acc
            case char {
              "." -> acc

              "#" -> #(
                dict.insert(obstacles, Position(row:, col:), Wall),
                robots,
                unknown,
              )

              "O" -> #(
                dict.insert(obstacles, Position(row:, col:), Box),
                robots,
                unknown,
              )

              "@" -> #(obstacles, [Position(row:, col:), ..robots], unknown)

              _ -> #(obstacles, robots, [Position(row:, col:), ..unknown])
            }
          },
        )
      },
    )

  use robot, extra_robots <- pop_or(robots, Error("No robots found"))

  use <- bool.guard(
    !list.is_empty(extra_robots),
    Error("There must be exactly one robot on the map"),
  )

  use <- bool.guard(
    !list.is_empty(unknown),
    Error(
      "Unknown chars at the following positions " <> string.inspect(unknown),
    ),
  )

  Ok(Map(dimensions:, obstacles:, robot:))
}

fn parse_directions(input: String) -> Result(List(Direction), String) {
  input
  |> string.to_graphemes()
  |> list.filter(fn(char) { char != "\n" })
  |> list.try_map(fn(char) {
    case char {
      "<" -> Ok(Left)
      ">" -> Ok(Right)
      "v" -> Ok(Down)
      "^" -> Ok(Up)
      _ -> Error("Unknown direction char " <> char)
    }
  })
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
