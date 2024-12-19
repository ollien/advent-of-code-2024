import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleamy/map
import gleamy/priority_queue

type Position {
  Position(row: Int, col: Int)
}

type TileKind {
  EmptyTile
  WallTile
  StartTile
  EndTile
}

type Direction {
  Up
  Down
  Left
  Right
}

type Reindeer {
  Reindeer(position: Position, direction: Direction)
}

type Map {
  Map(tiles: dict.Dict(Position, TileKind))
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use #(map, start, end) <- result.try(parse_input(input))

  io.println("Part 1: " <> part1(map, start, end))
  Ok(Nil)
}

fn part1(map: Map, start: Position, end: Position) -> String {
  shortest_path_cost(map, Reindeer(position: start, direction: Right), end)
  |> option.map(int.to_string)
  |> option.unwrap(or: "No solution found")
}

fn shortest_path_cost(
  map: Map,
  start_state: Reindeer,
  end: Position,
) -> option.Option(Int) {
  let to_visit =
    priority_queue.new(fn(a: #(Int, Reindeer), b: #(Int, Reindeer)) {
      int.compare(a.0, b.0)
    })

  do_shortest_path_cost(
    map,
    end,
    priority_queue.push(to_visit, #(0, start_state)),
    dict.from_list([#(start_state, 0)]),
  )
}

fn do_shortest_path_cost(
  map: Map,
  end: Position,
  to_visit: priority_queue.Queue(#(Int, Reindeer)),
  costs: dict.Dict(Reindeer, Int),
) -> option.Option(Int) {
  use #(#(distance, reindeer), to_visit) <- option.then(
    priority_queue.pop(to_visit) |> option.from_result,
  )
  use <- bool.guard(
    reindeer.position == end,
    return: dict.get(costs, reindeer) |> option.from_result(),
  )

  let valid_neighbor_costs =
    reindeer
    |> neighbor_costs()
    |> dict.filter(fn(neighbor, _cost) {
      dict.get(map.tiles, neighbor.position)
      |> result.map(fn(tile) { tile != WallTile })
      |> result.unwrap(or: False)
    })

  let #(to_visit, costs) =
    dict.fold(
      valid_neighbor_costs,
      from: #(to_visit, costs),
      with: fn(entry, neighbor, edge_cost) {
        let #(to_visit, costs) = entry
        let neighbor_cheaper =
          dict.get(costs, neighbor)
          |> result.map(fn(neighbor_cost) {
            distance + edge_cost < neighbor_cost
          })
          |> result.unwrap(or: True)

        case neighbor_cheaper {
          True -> #(
            priority_queue.push(to_visit, #(distance + edge_cost, neighbor)),
            dict.insert(costs, neighbor, distance + edge_cost),
          )
          False -> #(to_visit, costs)
        }
      },
    )

  do_shortest_path_cost(map, end, to_visit, costs)
}

fn parse_input(input: String) -> Result(#(Map, Position, Position), String) {
  let #(tiles, unknown, start_result, end_result) =
    input
    |> string.split("\n")
    |> list.index_fold(
      from: #(dict.new(), [], Ok(option.None), Ok(option.None)),
      with: fn(acc, line, row) {
        line
        |> string.to_graphemes()
        |> list.index_fold(from: acc, with: fn(acc, char, col) {
          let #(tiles, unknown, start, end) = acc
          let position = Position(row:, col:)
          let have_start =
            start |> result.map(option.is_some) |> result.unwrap(or: False)
          let have_end =
            start |> result.map(option.is_some) |> result.unwrap(or: False)

          case char {
            "#" -> #(
              dict.insert(tiles, position, WallTile),
              unknown,
              start,
              end,
            )
            "." -> #(
              dict.insert(tiles, position, EmptyTile),
              unknown,
              start,
              end,
            )
            "E" if have_end -> {
              #(
                tiles,
                unknown,
                start,
                Error("Cannot have more than one end tile"),
              )
            }
            "E" -> #(
              dict.insert(tiles, position, EndTile),
              unknown,
              start,
              Ok(option.Some(position)),
            )
            "S" if have_start -> {
              #(
                tiles,
                unknown,
                Error("Cannot have more than one start tile"),
                end,
              )
            }
            "S" -> #(
              dict.insert(tiles, position, EndTile),
              unknown,
              Ok(option.Some(position)),
              end,
            )
            _ -> #(tiles, [position, ..unknown], start, end)
          }
        })
      },
    )

  let start_result =
    start_result
    |> result.map(fn(maybe) {
      maybe
      |> option.map(Ok)
      |> option.unwrap(or: Error("No start tile found"))
    })
    |> result.flatten()

  let end_result =
    end_result
    |> result.map(fn(maybe) {
      maybe
      |> option.map(Ok)
      |> option.unwrap(or: Error("No end tile found"))
    })
    |> result.flatten()

  use <- bool.lazy_guard(!list.is_empty(unknown), return: fn() {
    Error("Unknown tiles in input at " <> string.inspect(unknown))
  })
  use start <- result.try(start_result)
  use end <- result.try(end_result)

  Ok(#(Map(tiles:), start, end))
}

fn neighbor_costs(reindeer: Reindeer) -> dict.Dict(Reindeer, Int) {
  reindeer.position
  |> neighbors()
  |> dict.to_list()
  |> list.map(fn(entry) {
    let #(position, direction) = entry
    let cost = case direction == reindeer.direction {
      True -> 1
      False -> 1001
    }

    #(Reindeer(position:, direction:), cost)
  })
  |> dict.from_list()
}

fn move_in_direction(position: Position, direction: Direction) -> Position {
  case direction {
    Up -> Position(..position, row: position.row - 1)
    Down -> Position(..position, row: position.row + 1)
    Left -> Position(..position, col: position.col - 1)
    Right -> Position(..position, col: position.col + 1)
  }
}

fn neighbors(position: Position) -> dict.Dict(Position, Direction) {
  dict.new()
  |> dict.insert(Position(..position, row: position.row - 1), Up)
  |> dict.insert(Position(..position, row: position.row + 1), Down)
  |> dict.insert(Position(..position, col: position.col + 1), Right)
  |> dict.insert(Position(..position, col: position.col - 1), Left)
}
