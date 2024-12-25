import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleam/string

type Position {
  Position(row: Int, col: Int)
}

type Map {
  Map(start: Position, end: Position, walls: set.Set(Position))
}

type PathStep {
  PathStep(position: Position, distance_from_start: Int)
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use map <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(map))
  io.println("Part 2: " <> part2(map))
  Ok(Nil)
}

fn part1(map: Map) -> String {
  case trace_path(map) {
    Error(err) -> err
    Ok(path) -> {
      find_cheat_paths(path, 2)
      |> dict.size()
      |> int.to_string()
    }
  }
}

fn part2(map: Map) -> String {
  case trace_path(map) {
    Error(err) -> err
    Ok(path) -> {
      list.range(from: 2, to: 20)
      |> list.fold(from: dict.new(), with: fn(acc, radius) {
        find_cheat_paths(path, radius)
        |> dict.combine(acc, int.max)
      })
      |> dict.size()
      |> int.to_string()
    }
  }
}

fn find_cheat_paths(
  path: List(PathStep),
  radius: Int,
) -> dict.Dict(#(Position, Position), Int) {
  do_find_cheat_paths(
    path,
    path
      |> list.map(fn(step) { #(step.position, step.distance_from_start) })
      |> dict.from_list(),
    radius,
    dict.new(),
  )
}

fn do_find_cheat_paths(
  path: List(PathStep),
  position_distances: dict.Dict(Position, Int),
  radius: Int,
  acc: dict.Dict(#(Position, Position), Int),
) -> dict.Dict(#(Position, Position), Int) {
  use path_head, path <- try_pop(path, or: acc)

  let acc =
    path_head.position
    |> manhattan_radius_from(radius)
    |> list.filter_map(fn(candidate) {
      use fair_distance <- result.try(dict.get(position_distances, candidate))
      let cheat_distance = path_head.distance_from_start + radius

      case cheat_distance < fair_distance {
        True if fair_distance - cheat_distance >= 100 -> {
          Ok(#(#(path_head.position, candidate), fair_distance - cheat_distance))
        }
        _ -> Error(Nil)
      }
    })
    |> list.fold(from: acc, with: fn(acc, cheat) {
      let #(cheat_key, new_savings) = cheat
      dict.upsert(acc, cheat_key, fn(existing) {
        case existing {
          option.Some(existing_savings) if existing_savings < new_savings ->
            existing_savings
          option.Some(_existing_distance) -> new_savings
          option.None -> new_savings
        }
      })
    })

  do_find_cheat_paths(path, position_distances, radius, acc)
}

fn trace_path(map: Map) -> Result(List(PathStep), String) {
  do_trace_path(map, map.start, set.new(), 0)
}

fn do_trace_path(
  map: Map,
  at: Position,
  visited: set.Set(Position),
  distance: Int,
) -> Result(List(PathStep), String) {
  use <- bool.guard(
    at == map.end,
    Ok([PathStep(position: map.end, distance_from_start: distance)]),
  )
  let next_candidates =
    list.filter(neighbors(at), fn(neighbor) {
      !set.contains(visited, neighbor) && !set.contains(map.walls, neighbor)
    })

  case next_candidates {
    [candidate] -> {
      use rest_path <- result.try(do_trace_path(
        map,
        candidate,
        set.insert(visited, at),
        distance + 1,
      ))

      Ok([PathStep(position: at, distance_from_start: distance), ..rest_path])
    }
    _ ->
      Error("Invariant violated: input must have exactly one path through it")
  }
}

fn parse_input(input: String) -> Result(Map, String) {
  let lines =
    input
    |> string.trim_end()
    |> string.split("\n")

  let tiles =
    lines
    |> list.index_fold(from: [], with: fn(acc, line, row) {
      list.index_fold(
        string.to_graphemes(line),
        from: acc,
        with: fn(acc, char, col) { [#(char, Position(row:, col:)), ..acc] },
      )
    })
    |> list.group(fn(pair) { pair.0 })

  use #(_, start) <- result.try(
    get_exactly_one(tiles, "S")
    |> result.map_error(fn(_nil) { "There must be exactly one start tile" }),
  )

  use #(_, end) <- result.try(
    get_exactly_one(tiles, "E")
    |> result.map_error(fn(_nil) { "There must be exactly one end tile" }),
  )

  let walls =
    tiles
    |> dict.get("#")
    |> result.unwrap(or: [])
    |> list.map(fn(pair) { pair.1 })
    |> set.from_list()

  Ok(Map(walls:, start:, end:))
}

fn get_exactly_one(d: dict.Dict(a, List(b)), key: a) -> Result(b, Nil) {
  case dict.get(d, key) {
    Ok([one]) -> Ok(one)
    Error(Nil) | Ok(_) -> Error(Nil)
  }
}

fn neighbors(position: Position) -> List(Position) {
  [
    Position(..position, row: position.row + 1),
    Position(..position, row: position.row - 1),
    Position(..position, col: position.col + 1),
    Position(..position, col: position.col - 1),
  ]
}

fn manhattan_radius_from(position: Position, radius: Int) -> List(Position) {
  use <- bool.guard(radius <= 0, [])

  // https://stackoverflow.com/questions/75128474/how-to-generate-all-of-the-coordinates-that-are-within-a-manhattan-distance-r-of
  list.flat_map(list.range(from: 0, to: radius - 1), fn(offset) {
    let inverse_offset = radius - offset
    [
      Position(row: position.row + inverse_offset, col: position.col + offset),
      Position(row: position.row - offset, col: position.col + inverse_offset),
      Position(row: position.row - inverse_offset, col: position.col - offset),
      Position(row: position.row + offset, col: position.col - inverse_offset),
    ]
  })
}

fn try_pop(l: List(a), or or: b, continue continue: fn(a, List(a)) -> b) -> b {
  case l {
    [] -> or
    [head, ..rest] -> continue(head, rest)
  }
}
