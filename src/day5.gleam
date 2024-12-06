import advent_of_code_2024
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/set
import gleam/string

type Page =
  Int

type Input {
  Input(rules: List(PageRule), updates: List(Update))
}

type PageRule {
  PageRule(first: Page, second: Page)
}

type Update {
  Update(pages: List(Page))
}

type Adjacencies =
  dict.Dict(Page, set.Set(Page))

pub fn main() {
  advent_of_code_2024.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use input <- result.try(parse_input(input))
  let adjacencies = build_adjacencies(input.rules)

  let #(valid_updates, fixed_updates) =
    input.updates
    |> list.map(fn(update) { #(update, make_valid_update(adjacencies, update)) })
    |> list.fold(from: #([], []), with: fn(acc, pair) {
      let #(original, fixed) = pair
      let #(valid_acc, fixed_acc) = acc
      case original == fixed {
        True -> #([original, ..valid_acc], fixed_acc)
        False -> #(valid_acc, [fixed, ..fixed_acc])
      }
    })

  io.println("Part 1: " <> calculate_middle_sum(valid_updates))
  io.println("Part 2: " <> calculate_middle_sum(fixed_updates))

  Ok(Nil)
}

fn calculate_middle_sum(valid_updates: List(Update)) -> String {
  valid_updates
  |> list.map(fn(update) {
    // These lists are guaranteed to be non-empty by our input parser
    let assert Ok(middle) = middle_element(update.pages)
    middle
  })
  |> int.sum()
  |> int.to_string()
}

fn make_valid_update(adjacencies: Adjacencies, update: Update) -> Update {
  let sorted_pages =
    list.sort(update.pages, fn(left, right) {
      compare_pages(adjacencies, left, right)
    })

  Update(sorted_pages)
}

fn compare_pages(
  adjacencies: Adjacencies,
  left: Page,
  right: Page,
) -> order.Order {
  // Must check both directions; what you don't want is an item that has no element that must come after it
  // but does have one that must come before it (29 and 23 in the example meet this criteria)
  let left_order =
    adjacencies
    |> dict.get(left)
    |> result.map(fn(left_adj) {
      case set.contains(left_adj, right) {
        True -> order.Lt
        False -> order.Gt
      }
    })

  let right_order =
    adjacencies
    |> dict.get(right)
    |> result.map(fn(right_adj) {
      case set.contains(right_adj, left) {
        True -> order.Gt
        False -> order.Lt
      }
    })

  result.or(left_order, right_order)
  |> result.unwrap(or: order.Eq)
}

fn middle_element(items: List(a)) -> Result(a, Nil) {
  let length = list.length(items)
  let middle_index = length / 2

  items
  |> list.drop(middle_index)
  |> list.first()
}

fn build_adjacencies(page_rules: List(PageRule)) -> Adjacencies {
  list.fold(page_rules, from: dict.new(), with: fn(adjacencies, rule) {
    dict.upsert(adjacencies, rule.first, fn(existing) {
      case existing {
        option.None -> set.from_list([rule.second])
        option.Some(rules) -> set.insert(rules, rule.second)
      }
    })
  })
}

fn parse_input(input: String) -> Result(Input, String) {
  let input_sections =
    input
    |> string.split("\n\n")
    |> list.map(string.trim_end)

  case input_sections {
    [raw_page_rules, raw_updates] -> {
      use rules <- result.try(parse_page_rules(raw_page_rules))
      use updates <- result.try(parse_updates(raw_updates))

      Ok(Input(rules:, updates:))
    }

    _ -> Error("Malformed input; input must have two sections")
  }
}

fn parse_page_rules(input: String) -> Result(List(PageRule), String) {
  input
  |> string.split("\n")
  |> list.try_map(parse_page_rule)
}

fn parse_updates(input: String) -> Result(List(Update), String) {
  input
  |> string.split("\n")
  |> list.try_map(parse_update)
}

fn parse_page_rule(line: String) -> Result(PageRule, String) {
  case string.split(line, "|") {
    [first, second] -> {
      use first <- result.try(parse_int(first))
      use second <- result.try(parse_int(second))

      Ok(PageRule(first:, second:))
    }

    _ -> Error("Malformed page rule; must have two portions")
  }
}

fn parse_update(line: String) -> Result(Update, String) {
  use <- bool.guard(
    string.is_empty(line),
    return: Error("An update cannot have zero pages"),
  )

  line
  |> string.split(",")
  |> list.try_map(parse_int)
  |> result.map(fn(pages) { Update(pages:) })
}

fn parse_int(s: String) -> Result(Int, String) {
  s
  |> int.parse()
  |> result.map_error(fn(_nil) { "Malformed int " <> s })
}
