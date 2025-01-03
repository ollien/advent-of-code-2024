import advent_of_code_2024
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/result
import gleam/string

type Address =
  Int

type Id =
  Int

type File {
  File(size: Int, id: Int)
}

type BlankSpace {
  BlankSpace(size: Int)
}

type Disk {
  Disk(
    used_spans: dict.Dict(Address, File),
    free_spans: dict.Dict(Address, BlankSpace),
  )
}

type DefragMode {
  SpreadFileDefragMode
  ColocateFileDefragMode
}

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use input <- result.try(parse_input(input))

  io.print_error("")

  io.println("Part 1: " <> part1(input))
  io.println("Part 2: " <> part2(input))

  Ok(Nil)
}

fn part1(disk: Disk) -> String {
  let disk = defrag(disk, SpreadFileDefragMode)

  disk.used_spans
  |> checksum()
  |> int.to_string()
}

fn part2(disk: Disk) -> String {
  let disk = defrag(disk, ColocateFileDefragMode)

  disk.used_spans
  |> checksum()
  |> int.to_string()
}

fn checksum(files: dict.Dict(Address, File)) -> Int {
  files
  |> dict.to_list
  |> list.fold(from: 0, with: fn(acc, entry) {
    let #(addr, File(id:, size:)) = entry
    let next_operand =
      list.fold(list.range(from: addr, to: addr + size - 1), 0, fn(acc, addr) {
        acc + addr * id
      })

    acc + next_operand
  })
}

fn defrag(disk: Disk, mode: DefragMode) -> Disk {
  let file_addresses =
    disk.used_spans
    |> dict.keys()
    |> list.sort(order.reverse(int.compare))

  let free_addresses =
    disk.free_spans
    |> dict.keys()
    |> list.sort(int.compare)

  do_defrag(disk, file_addresses, free_addresses, mode)
}

fn do_defrag(
  disk: Disk,
  files_to_defrag: List(Address),
  free_addresses: List(Address),
  mode: DefragMode,
) -> Disk {
  use file_addr, files_to_defrag <- try_pop(files_to_defrag, or: disk)
  // This is guaranteed by construction of files_to_defrag
  let assert Ok(file) = dict.get(disk.used_spans, file_addr)
  let disk = delete_file(disk, file_addr)

  case
    collect_space_for_file(
      disk,
      file,
      file_addr,
      file.size,
      sorted_insert(file_addr, free_addresses),
      mode,
    )
  {
    // Can't defrag anymore
    Error(Nil) -> disk
    Ok(#(disk, space_to_use, free_addresses)) -> {
      let #(disk, _space) =
        list.fold(space_to_use, from: #(disk, file.size), with: fn(acc, space) {
          let #(disk, space_left) = acc
          let #(address, span) = space

          let space_to_put_in_span = int.min(span.size, space_left)
          let disk =
            store_file(
              disk,
              address,
              File(id: file.id, size: space_to_put_in_span),
            )

          #(disk, space_left - space_to_put_in_span)
        })

      do_defrag(disk, files_to_defrag, free_addresses, mode)
    }
  }
}

fn delete_file(disk: Disk, address: Address) -> Disk {
  case dict.get(disk.used_spans, address) {
    Error(Nil) -> disk

    Ok(file) -> {
      Disk(
        free_spans: dict.insert(
          disk.free_spans,
          address,
          BlankSpace(size: file.size),
        ),
        used_spans: dict.delete(disk.used_spans, address),
      )
    }
  }
}

fn store_file(disk: Disk, address: Address, file: File) -> Disk {
  Disk(..disk, used_spans: dict.insert(disk.used_spans, address, file))
}

fn collect_space_for_file(
  disk: Disk,
  file: File,
  file_addr: Address,
  space_needed: Int,
  free_addresses: List(Address),
  mode: DefragMode,
) -> Result(#(Disk, List(#(Address, BlankSpace)), List(Address)), Nil) {
  use space_addr, free_addresses <- try_pop(free_addresses, or: Error(Nil))

  // This is guaranteed by construction of free_addresses
  let assert Ok(span) = dict.get(disk.free_spans, space_addr)
  case int.compare(span.size, space_needed), mode {
    order.Eq, _any_mode -> {
      let disk =
        Disk(..disk, free_spans: dict.delete(disk.free_spans, space_addr))
      Ok(#(disk, [#(space_addr, span)], free_addresses))
    }

    order.Gt, _any_mode -> {
      let free_spans =
        disk.free_spans
        |> dict.delete(space_addr)
        |> dict.insert(
          space_addr + space_needed,
          BlankSpace(span.size - space_needed),
        )

      let disk = Disk(..disk, free_spans:)
      Ok(
        #(disk, [#(space_addr, span)], [
          space_addr + space_needed,
          ..free_addresses
        ]),
      )
    }

    order.Lt, SpreadFileDefragMode -> {
      let disk =
        Disk(..disk, free_spans: dict.delete(disk.free_spans, space_addr))

      use #(disk, space_to_use, free_addresses) <- result.try(
        collect_space_for_file(
          disk,
          file,
          file_addr,
          space_needed - span.size,
          free_addresses,
          mode,
        ),
      )

      Ok(#(disk, [#(space_addr, span), ..space_to_use], free_addresses))
    }

    order.Lt, ColocateFileDefragMode -> {
      use #(disk, space_to_use, free_addresses) <- result.try(
        collect_space_for_file(
          disk,
          file,
          file_addr,
          space_needed,
          free_addresses,
          mode,
        ),
      )

      Ok(#(disk, space_to_use, [space_addr, ..free_addresses]))
    }
  }
}

fn parse_input(input: String) -> Result(Disk, String) {
  let input = string.trim_end(input)
  use sequence <- result.try(parse_int_sequence(input))

  Ok(parse_input_sequence(sequence))
}

fn parse_input_sequence(sequence: List(Int)) -> Disk {
  do_parse_input_sequence(
    sequence,
    0,
    0,
    Disk(used_spans: dict.new(), free_spans: dict.new()),
  )
}

fn do_parse_input_sequence(
  sequence sequence: List(Int),
  next_id next_id: Id,
  next_address next_address: Address,
  acc acc: Disk,
) -> Disk {
  case sequence {
    [] -> acc
    [file_width] -> {
      Disk(
        ..acc,
        used_spans: dict.insert(
          acc.used_spans,
          next_address,
          File(id: next_id, size: file_width),
        ),
      )
    }

    [file_width, free_width, ..rest_sequence] if free_width == 0 -> {
      let acc =
        Disk(
          ..acc,
          used_spans: dict.insert(
            acc.used_spans,
            next_address,
            File(id: next_id, size: file_width),
          ),
        )

      do_parse_input_sequence(
        rest_sequence,
        next_id: next_id + 1,
        next_address: next_address + file_width + free_width,
        acc:,
      )
    }

    [file_width, free_width, ..rest_sequence] -> {
      let acc =
        Disk(
          used_spans: dict.insert(
            acc.used_spans,
            next_address,
            File(id: next_id, size: file_width),
          ),
          free_spans: dict.insert(
            acc.free_spans,
            next_address + file_width,
            BlankSpace(size: free_width),
          ),
        )

      do_parse_input_sequence(
        rest_sequence,
        next_id: next_id + 1,
        next_address: next_address + file_width + free_width,
        acc:,
      )
    }
  }
}

fn parse_int_sequence(s: String) -> Result(List(Int), String) {
  s
  |> string.to_graphemes()
  |> list.try_map(parse_int)
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

fn sorted_insert(n: Int, list: List(Int)) -> List(Int) {
  case list {
    [] -> [n]

    [m, ..rest] if m <= n -> {
      [m, ..sorted_insert(n, rest)]
    }

    [_m, ..] -> {
      [n, ..list]
    }
  }
}
