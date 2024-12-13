import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/set
import gleam/string

type Id =
  Int

type Position {
  Position(row: Int, col: Int)
}

type RawMap {
  RawMap(tiles: dict.Dict(Position, String))
}

type Region {
  Region(key: String, tiles: List(Position))
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  let raw_map = parse_input(input)
  let regions = build_regions(raw_map)

  io.println("Part 1: " <> part1(raw_map, regions))
  io.println("Part 2: " <> part2(regions))

  Ok(Nil)
}

fn part1(raw_map: RawMap, regions: List(Region)) -> String {
  regions
  |> list.map(fn(region) {
    list.length(region.tiles) * region_perimeter(raw_map, region)
  })
  |> int.sum()
  |> int.to_string()
}

fn part2(regions: List(Region)) -> String {
  regions
  |> list.map(fn(region) { list.length(region.tiles) * region_edges(region) })
  |> int.sum()
  |> int.to_string()
}

fn region_perimeter(raw_map: RawMap, region: Region) -> Int {
  let positions = set.from_list(region.tiles)
  do_region_perimeter(raw_map, region.tiles, positions)
}

fn do_region_perimeter(
  raw_map: RawMap,
  to_check: List(Position),
  known_positions: set.Set(Position),
) -> Int {
  use tile, to_check <- try_pop(to_check, or: 0)

  let subtract =
    cardinal_neighbors(tile)
    |> list.filter(fn(position) { dict.has_key(raw_map.tiles, position) })
    |> set.from_list()
    |> set.intersection(known_positions)
    |> set.size()

  { 4 - subtract } + do_region_perimeter(raw_map, to_check, known_positions)
}

fn region_edges(region: Region) -> Int {
  do_region_edges(set.from_list(region.tiles), region.tiles, set.new(), 0)
}

fn do_region_edges(
  region_tiles: set.Set(Position),
  to_visit: List(Position),
  visited: set.Set(Position),
  corners: Int,
) -> Int {
  use visiting, to_visit <- try_pop(to_visit, or: corners)
  use <- bool.lazy_guard(set.contains(visited, visiting), fn() {
    do_region_edges(region_tiles, to_visit, visited, corners)
  })

  let visited = set.insert(visited, visiting)

  let convex_check = [
    #(up_neighbor(visiting), left_neighbor(visiting)),
    #(up_neighbor(visiting), right_neighbor(visiting)),
    #(down_neighbor(visiting), left_neighbor(visiting)),
    #(down_neighbor(visiting), right_neighbor(visiting)),
  ]

  let convex =
    list.count(convex_check, fn(to_check) {
      let #(a, b) = to_check
      !set.contains(region_tiles, a) && !set.contains(region_tiles, b)
    })

  let concave_check = [
    #(
      up_neighbor(visiting),
      left_neighbor(visiting),
      up_left_neighbor(visiting),
    ),
    #(
      up_neighbor(visiting),
      right_neighbor(visiting),
      up_right_neighbor(visiting),
    ),
    #(
      down_neighbor(visiting),
      left_neighbor(visiting),
      down_left_neighbor(visiting),
    ),
    #(
      down_neighbor(visiting),
      right_neighbor(visiting),
      down_right_neighbor(visiting),
    ),
  ]

  let concave =
    list.count(concave_check, fn(to_check) {
      let #(a, b, c) = to_check
      set.contains(region_tiles, a)
      && set.contains(region_tiles, b)
      && !set.contains(region_tiles, c)
    })

  do_region_edges(region_tiles, to_visit, visited, corners + convex + concave)
}

fn build_regions(raw_map: RawMap) -> List(Region) {
  do_build_regions(
    raw_map:,
    to_visit: [#(Position(row: 0, col: 0), 0)],
    regions: dict.new(),
    visited: set.new(),
    next_id: 1,
  )
}

fn do_build_regions(
  raw_map raw_map: RawMap,
  to_visit to_visit: List(#(Position, Id)),
  regions regions: dict.Dict(Id, Region),
  visited visited: set.Set(Position),
  next_id next_id: Id,
) -> List(Region) {
  use head, to_visit <- try_pop_lazy(to_visit, or: fn() { dict.values(regions) })

  let #(visiting, id) = head
  use <- bool.lazy_guard(set.contains(visited, visiting), fn() {
    do_build_regions(raw_map:, to_visit:, regions:, visited:, next_id:)
  })

  let visited = set.insert(visited, visiting)

  // to_visit will not be populated with unknown tiles
  let assert Ok(region_key) = dict.get(raw_map.tiles, visiting)
  let current_region =
    regions
    |> dict.get(id)
    |> result.map(fn(region) {
      Region(..region, tiles: [visiting, ..region.tiles])
    })
    |> result.lazy_unwrap(or: fn() {
      Region(key: region_key, tiles: [visiting])
    })

  let #(region_neighbors, nonregion_neighbors) =
    visiting
    |> cardinal_neighbors()
    |> list.filter_map(fn(position) {
      raw_map.tiles
      |> dict.get(position)
      |> result.map(fn(key) { #(position, key) })
    })
    |> list.partition(fn(entry) {
      let #(_position, key) = entry
      key == region_key
    })

  let region_neighbors = list.map(region_neighbors, fn(entry) { entry.0 })
  let nonregion_neighbors = list.map(nonregion_neighbors, fn(entry) { entry.0 })

  let regions = dict.insert(regions, id, current_region)

  let to_visit =
    list.fold(region_neighbors, from: to_visit, with: fn(acc, position) {
      [#(position, id), ..acc]
    })

  case nonregion_neighbors {
    [] -> {
      do_build_regions(raw_map:, to_visit:, regions:, visited:, next_id:)
    }
    // Use the first tile we have of a nonregion neighbor. We can't easily group all the neighbor's IDs together,
    // so by taking just one that we know must be of a new region, we let that one dictate its future neighbors
    [head, ..] -> {
      do_build_regions(
        raw_map:,
        to_visit: list.append(to_visit, [#(head, next_id)]),
        regions:,
        visited:,
        next_id: next_id + 1,
      )
    }
  }
}

fn cardinal_neighbors(position: Position) -> List(Position) {
  [
    up_neighbor(position),
    down_neighbor(position),
    left_neighbor(position),
    right_neighbor(position),
  ]
}

fn up_neighbor(position: Position) -> Position {
  Position(..position, row: position.row - 1)
}

fn down_neighbor(position: Position) -> Position {
  Position(..position, row: position.row + 1)
}

fn left_neighbor(position: Position) -> Position {
  Position(..position, col: position.col - 1)
}

fn right_neighbor(position: Position) -> Position {
  Position(..position, col: position.col + 1)
}

fn up_left_neighbor(position: Position) -> Position {
  Position(row: position.row - 1, col: position.col - 1)
}

fn up_right_neighbor(position: Position) -> Position {
  Position(row: position.row - 1, col: position.col + 1)
}

fn down_left_neighbor(position: Position) -> Position {
  Position(row: position.row + 1, col: position.col - 1)
}

fn down_right_neighbor(position: Position) -> Position {
  Position(row: position.row + 1, col: position.col + 1)
}

fn parse_input(input: String) -> RawMap {
  let tiles =
    input
    |> string.trim_end()
    |> string.split("\n")
    |> list.index_fold(from: dict.new(), with: fn(acc, line, row) {
      line
      |> string.to_graphemes()
      |> list.index_fold(from: acc, with: fn(acc, char, col) {
        dict.insert(acc, Position(row:, col:), char)
      })
    })

  RawMap(tiles: tiles)
}

fn try_pop(l: List(a), or or: b, continue continue: fn(a, List(a)) -> b) -> b {
  case l {
    [] -> or
    [head, ..rest] -> continue(head, rest)
  }
}

fn try_pop_lazy(
  l: List(a),
  or or: fn() -> b,
  continue continue: fn(a, List(a)) -> b,
) -> b {
  case l {
    [] -> or()
    [head, ..rest] -> continue(head, rest)
  }
}
