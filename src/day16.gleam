import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
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

  let res =
    shortest_paths_cost(map, Reindeer(position: start, direction: Right), end)
  case res {
    option.None -> io.println("No solution found")
    option.Some(#(part1, part2)) -> {
      io.println("Part 1: " <> int.to_string(part1))
      io.println("Part 2: " <> int.to_string(part2))
    }
  }

  Ok(Nil)
}

fn shortest_paths_cost(
  map: Map,
  start_state: Reindeer,
  end: Position,
) -> option.Option(#(Int, Int)) {
  let to_visit =
    priority_queue.new(fn(a: #(Int, Reindeer), b: #(Int, Reindeer)) {
      int.compare(a.0, b.0)
    })
  let #(solved_cost, parents) =
    do_shortest_path_cost(
      map,
      end,
      priority_queue.push(to_visit, #(0, start_state)),
      dict.new(),
      dict.from_list([#(start_state, 0)]),
    )

  option.map(solved_cost, fn(cost) {
    let assert Ok(parent_reindeer) =
      dict.keys(parents)
      |> list.find(fn(parent) { parent.position == end })

    let num_shortest_path_locations =
      shortest_paths_locations(parent_reindeer, start_state.position, parents)
      |> list.unique()
      |> list.length()

    #(cost, num_shortest_path_locations)
  })
}

fn shortest_paths_locations(
  end: Reindeer,
  start: Position,
  parents: dict.Dict(Reindeer, List(Reindeer)),
) -> List(Position) {
  use <- bool.guard(end.position == start, return: [])
  dict.get(parents, end)
  |> result.unwrap(or: [])
  |> list.fold(from: [end.position], with: fn(acc, parent) {
    list.flatten([
      [parent.position, ..acc],
      shortest_paths_locations(parent, start, parents),
    ])
  })
}

fn do_shortest_path_cost(
  map: Map,
  end: Position,
  to_visit: priority_queue.Queue(#(Int, Reindeer)),
  parents: dict.Dict(Reindeer, List(Reindeer)),
  costs: dict.Dict(Reindeer, Int),
) -> #(option.Option(Int), dict.Dict(Reindeer, List(Reindeer))) {
  let popped = priority_queue.pop(to_visit) |> option.from_result
  use <- bool.guard(!option.is_some(popped), return: #(option.None, parents))
  let assert option.Some(#(#(distance, reindeer), to_visit)) = popped

  use <- bool.guard(reindeer.position == end, return: #(
    dict.get(costs, reindeer) |> option.from_result(),
    parents,
  ))

  let valid_neighbor_costs =
    reindeer
    |> neighbor_costs()
    |> dict.filter(fn(neighbor, _cost) {
      dict.get(map.tiles, neighbor.position)
      |> result.map(fn(tile) { tile != WallTile })
      |> result.unwrap(or: False)
    })

  let #(to_visit, costs, parents) =
    dict.fold(
      valid_neighbor_costs,
      from: #(to_visit, costs, parents),
      with: fn(entry, neighbor, edge_cost) {
        let #(to_visit, costs, parents) = entry
        let neighbor_cost_cmp =
          dict.get(costs, neighbor)
          |> result.map(fn(neighbor_cost) {
            int.compare(distance + edge_cost, neighbor_cost)
          })
          |> result.unwrap(or: order.Lt)

        case neighbor_cost_cmp {
          order.Lt -> #(
            priority_queue.push(to_visit, #(distance + edge_cost, neighbor)),
            dict.insert(costs, neighbor, distance + edge_cost),
            dict.insert(parents, neighbor, [reindeer]),
          )
          order.Eq -> {
            // io.debug(#(reindeer, neighbor, distance + edge_cost))
            #(
              to_visit,
              costs,
              dict.upsert(parents, neighbor, fn(maybe) {
                let local_parents = option.unwrap(maybe, or: [])
                [reindeer, ..local_parents]
              }),
            )
          }
          order.Gt -> #(to_visit, costs, parents)
        }
      },
    )

  do_shortest_path_cost(map, end, to_visit, parents, costs)
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
              dict.insert(tiles, position, StartTile),
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

fn neighbors(position: Position) -> dict.Dict(Position, Direction) {
  dict.new()
  |> dict.insert(Position(..position, row: position.row - 1), Up)
  |> dict.insert(Position(..position, row: position.row + 1), Down)
  |> dict.insert(Position(..position, col: position.col + 1), Right)
  |> dict.insert(Position(..position, col: position.col - 1), Left)
}
