import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/function
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
    obstacles: dict.Dict(Position, Hull),
    robot: Position,
  )
}

type Hull {
  Hull(obstacle_type: Obstacle, width: Int)
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
  use #(map2, directions2) <- result.try(parse_and_scale_input(input))

  io.println("Part 1: " <> solve(map, directions))
  io.println("Part 2: " <> solve(map2, directions2))
  Ok(Nil)
}

fn solve(map: Map, directions: List(Direction)) -> String {
  let upd_map = simulate(map, directions)

  upd_map.obstacles
  |> dict.filter(fn(_position, hull) { hull.obstacle_type == Box })
  |> dict.keys()
  |> list.map(fn(position) { position.row * 100 + position.col })
  |> int.sum()
  |> int.to_string()
}

fn simulate(map: Map, directions: List(Direction)) -> Map {
  use direction, directions <- pop_or(directions, or: map)
  let robot_candidate = move_in_direction(map.robot, direction)

  let map = case lookup_obstacle(map, robot_candidate) {
    Ok(#(hull_root, hull)) -> {
      case hull.obstacle_type {
        Wall -> map
        Box -> {
          try_move_box(map, hull, hull_root, direction)
          |> result.map(fn(map) { Map(..map, robot: robot_candidate) })
          |> result.unwrap(or: map)
        }
      }
    }
    Error(Nil) -> Map(..map, robot: robot_candidate)
  }

  simulate(map, directions)
}

fn lookup_obstacle(
  map: Map,
  position: Position,
) -> Result(#(Position, Hull), Nil) {
  map.obstacles
  |> dict.get(position)
  |> result.map(fn(hull) { #(position, hull) })
  |> result.try_recover(fn(_nil) {
    // We know that our widest hull is going to be two-wide, so if there's nothing there,
    // we look left to see if there's a hull
    let alternate_position = Position(..position, col: position.col - 1)
    case dict.get(map.obstacles, alternate_position) {
      Ok(Hull(width:, ..) as hull) if width > 1 -> {
        Ok(#(alternate_position, hull))
      }
      Ok(_any) | Error(Nil) -> Error(Nil)
    }
  })
}

fn hull_neighbors_in_direction(
  map: Map,
  hull: Hull,
  root: Position,
  direction: Direction,
) -> List(Position) {
  let inside_hull = hull_positions(hull, root)

  list.filter_map(inside_hull, fn(position) {
    let neighbor = move_in_direction(position, direction)
    case list.contains(inside_hull, neighbor) {
      True -> Error(Nil)
      False -> Ok(neighbor)
    }
  })
}

fn hull_positions(hull: Hull, root: Position) {
  case hull.width > 0 {
    True -> Nil
    False -> panic as "hull width cannot be negative"
  }

  list.fold(
    list.range(from: 0, to: hull.width - 1),
    from: [],
    with: fn(acc, col_offset) {
      [Position(..root, col: root.col + col_offset), ..acc]
    },
  )
}

fn try_move_box(
  map: Map,
  hull: Hull,
  root: Position,
  direction: Direction,
) -> Result(Map, Nil) {
  use affected_neighbors <- result.map(locate_affected_obstacles(
    map,
    hull,
    root,
    direction,
  ))

  let affected_obstacles = [#(root, hull), ..affected_neighbors]
  let cleaned_obstacles =
    list.fold(
      affected_obstacles,
      from: map.obstacles,
      with: fn(obstacles, entry) {
        let #(position, _obstacle) = entry
        dict.delete(obstacles, position)
      },
    )
  let updated_obstacles =
    list.fold(
      affected_obstacles,
      from: cleaned_obstacles,
      with: fn(obstacles, entry) {
        let #(position, obstacle) = entry

        dict.insert(obstacles, move_in_direction(position, direction), obstacle)
      },
    )

  Map(..map, obstacles: updated_obstacles)
}

fn locate_affected_obstacles(
  map: Map,
  hull: Hull,
  root: Position,
  direction: Direction,
) -> Result(List(#(Position, Hull)), Nil) {
  let neighbors = hull_neighbors_in_direction(map, hull, root, direction)
  let neighboring_obstacles =
    list.filter_map(neighbors, fn(neighbor) { lookup_obstacle(map, neighbor) })
  let grouped_obstacles =
    list.group(neighboring_obstacles, fn(entry) {
      let #(_position, hull) = entry
      hull.obstacle_type
    })

  case dict.get(grouped_obstacles, Wall) |> result.unwrap(or: []) {
    [] -> {
      let boxes = dict.get(grouped_obstacles, Box) |> result.unwrap(or: [])
      boxes
      |> list.try_map(fn(box) {
        let #(neighbor_hull_root, neighbor_hull) = box
        locate_affected_obstacles(
          map,
          neighbor_hull,
          neighbor_hull_root,
          direction,
        )
      })
      |> result.map(fn(affected) { [#(root, hull), ..list.flatten(affected)] })
    }
    [_walls, ..] -> {
      Error(Nil)
    }
  }
}

fn do_try_move_box(
  map: Map,
  box_location: Position,
  direction: Direction,
) -> Result(Map, Nil) {
  let position_candidate = move_in_direction(box_location, direction)
  case dict.get(map.obstacles, position_candidate) {
    Ok(Hull(obstacle_type: Box, ..)) -> {
      do_try_move_box(map, position_candidate, direction)
    }

    Ok(Hull(obstacle_type: Wall, ..)) -> Error(Nil)

    Error(Nil) -> {
      Ok(
        Map(
          ..map,
          obstacles: dict.insert(
            map.obstacles,
            position_candidate,
            Hull(obstacle_type: Box, width: 1),
          ),
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
  do_parse_input(input, function.identity)
}

fn parse_and_scale_input(
  input: String,
) -> Result(#(Map, List(Direction)), String) {
  let parse_result =
    do_parse_input(input, fn(raw_map) {
      raw_map
      |> string.replace(".", "..")
      |> string.replace("#", "##")
      |> string.replace("@", "@.")
      // We will replace these with big boxes soon, but for now just make the whole map twice as wide
      |> string.replace("O", "O.")
    })
  use #(map, directions) <- result.try(parse_result)

  let obstacles =
    map.obstacles
    |> dict.map_values(fn(_position, hull) {
      case hull.obstacle_type {
        Wall -> hull
        Box -> {
          Hull(obstacle_type: Box, width: 2)
        }
      }
    })

  Ok(#(Map(..map, obstacles:), directions))
}

fn do_parse_input(
  input: String,
  transform_raw_map: fn(String) -> String,
) -> Result(#(Map, List(Direction)), String) {
  let input_components =
    input
    |> string.trim_end()
    |> string.split("\n\n")

  case input_components {
    [raw_map, raw_directions] -> {
      use map <- result.try(parse_map(transform_raw_map(raw_map)))
      use directions <- result.try(parse_directions(raw_directions))

      Ok(#(map, directions))
    }

    _ -> Error("input must have exactly two sections")
  }
}

fn parse_map(input: String) -> Result(Map, String) {
  let input_lines = string.split(input, "\n")
  use dimensions <- result.try(measure_input(input_lines))

  let #(obstacle_hulls, robots, unknown) =
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
                dict.insert(
                  obstacles,
                  Position(row:, col:),
                  Hull(obstacle_type: Wall, width: 1),
                ),
                robots,
                unknown,
              )

              "O" -> #(
                dict.insert(
                  obstacles,
                  Position(row:, col:),
                  Hull(obstacle_type: Box, width: 1),
                ),
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

  Ok(Map(dimensions:, obstacles: obstacle_hulls, robot:))
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
