///|
const VERSION : String = "0.1.0"

///|
const USAGE : String =
  #|moon-codeowners - deterministic CODEOWNERS audit tool
  #|
  #|Usage:
  #|  moon-codeowners check <CODEOWNERS> [paths-file] [--json]
  #|  moon-codeowners owners <CODEOWNERS> <repo-path>
  #|  moon-codeowners explain <CODEOWNERS> <repo-path>
  #|  moon-codeowners coverage <CODEOWNERS> <paths-file> [--json]
  #|
  #|A paths file contains one repository-relative path per line.
  #|`check` exits with an error when parsing or coverage checks fail.

///|
async fn main {
  let raw_args = @env.args()
  let args = []
  let mut index = 1
  while index < raw_args.length() {
    args.push(raw_args[index])
    index = index + 1
  }
  if args.is_empty() {
    println(USAGE)
    return
  }
  let command = args[0]
  if command == "help" || command == "--help" || command == "-h" {
    println(USAGE)
    return
  }
  if command == "version" || command == "--version" || command == "-V" {
    println("moon-codeowners \{VERSION}")
    return
  }
  let (positionals, json_mode) = parse_flags(args)
  match command {
    "owners" => run_owners(positionals)
    "explain" => run_explain(positionals)
    "coverage" => run_coverage(positionals, json_mode)
    "check" => {
      let ok = run_check(positionals, json_mode)
      if !ok {
        abort("CODEOWNERS check failed")
      }
    }
    _ => {
      println("unknown command: \{command}")
      println(USAGE)
      abort("unknown command")
    }
  }
}

///|
fn parse_flags(args : Array[String]) -> (Array[String], Bool) {
  let positionals = []
  let mut json_mode = false
  for index in 1..<args.length() {
    let arg = args[index]
    if arg == "--json" {
      json_mode = true
    } else {
      positionals.push(arg)
    }
  }
  (positionals, json_mode)
}

///|
async fn read_text(path : String) -> String {
  @fs.read_file(path).text()
}

///|
async fn read_paths(path : String) -> Array[String] {
  let text = read_text(path)
  let paths = []
  for line in text.split("\n") {
    let value = line.trim().to_owned()
    if !value.is_empty() {
      paths.push(value)
    }
  }
  paths
}

///|
async fn load_document(path : String) -> @lib.Codeowners {
  @lib.Codeowners::parse(read_text(path))
}

///|
fn print_issues(issues : Array[@lib.ParseIssue]) -> Unit {
  for issue in issues {
    println("line \{issue.line}: \{issue.message}: \{issue.source}")
  }
}

///|
async fn run_owners(positionals : Array[String]) -> Unit {
  if positionals.length() != 2 {
    println("usage: moon-codeowners owners <CODEOWNERS> <repo-path>")
    abort("invalid arguments")
  }
  let document = load_document(positionals[0])
  print_issues(document.issues)
  print_owner_list(document.owners_for(positionals[1]))
}

///|
async fn run_explain(positionals : Array[String]) -> Unit {
  if positionals.length() != 2 {
    println("usage: moon-codeowners explain <CODEOWNERS> <repo-path>")
    abort("invalid arguments")
  }
  let document = load_document(positionals[0])
  print_issues(document.issues)
  let path = positionals[1]
  match document.find_rule(path) {
    Some(rule) => {
      println("path: \{path}")
      println("pattern: \{rule.pattern}")
      println("line: \{rule.line}")
      println("owners: \{owner_list_text(rule.owners)}")
    }
    None => println("\{path}: unowned")
  }
}

///|
async fn run_coverage(positionals : Array[String], json_mode : Bool) -> Unit {
  if positionals.length() != 2 {
    println(
      "usage: moon-codeowners coverage <CODEOWNERS> <paths-file> [--json]",
    )
    abort("invalid arguments")
  }
  let document = load_document(positionals[0])
  let paths = read_paths(positionals[1])
  let report = document.audit(paths)
  if json_mode {
    println(report_json(report))
    return
  }
  print_issues(report.issues)
  for entry in report.entries {
    match entry.matched_pattern {
      Some(pattern) =>
        println(
          "covered   \{entry.path}  <- \{pattern} (line \{entry.matched_line.unwrap()})",
        )
      None => println("UNCOVERED \{entry.path}")
    }
  }
  println(
    "coverage: \{report.covered_count}/\{report.total_count} paths, \{report.uncovered.length()} uncovered",
  )
}

///|
async fn run_check(positionals : Array[String], json_mode : Bool) -> Bool {
  if positionals.is_empty() || positionals.length() > 2 {
    println("usage: moon-codeowners check <CODEOWNERS> [paths-file] [--json]")
    return false
  }
  let document = load_document(positionals[0])
  let paths = if positionals.length() == 2 {
    read_paths(positionals[1])
  } else {
    []
  }
  let report = document.audit(paths)
  let ok = report.issues.is_empty() && report.uncovered.is_empty()
  if json_mode {
    println(check_json(document, report, ok))
  } else {
    print_issues(report.issues)
    for path in report.uncovered {
      println("UNCOVERED \{path}")
    }
    if ok {
      if report.total_count == 0 {
        println(
          "OK: \{document.rule_count()} rules parsed; no changed-files input supplied",
        )
      } else {
        println(
          "OK: \{document.rule_count()} rules parsed; all \{report.total_count} paths are covered",
        )
      }
    } else {
      println(
        "FAILED: \{report.issues.length()} parse issues, \{report.uncovered.length()} uncovered paths",
      )
    }
  }
  ok
}

///|
fn owner_list_text(owners : Array[@lib.Owner]) -> String {
  let values = []
  for owner in owners {
    values.push(owner.raw)
  }
  values.join(" ")
}

///|
fn print_owner_list(owners : Array[@lib.Owner]) -> Unit {
  if owners.is_empty() {
    println("(unowned)")
  } else {
    println(owner_list_text(owners))
  }
}

///|
fn check_json(
  document : @lib.Codeowners,
  report : @lib.AuditReport,
  ok : Bool,
) -> String {
  let builder = StringBuilder()
  builder.write_string("{\"valid\":")
  builder.write_string(if ok { "true" } else { "false" })
  builder.write_string(",\"rules\":")
  builder.write_string(document.rule_count().to_string())
  builder.write_string(",\"covered\":")
  builder.write_string(report.covered_count.to_string())
  builder.write_string(",\"total\":")
  builder.write_string(report.total_count.to_string())
  builder.write_string(",\"issues\":")
  write_issues_json(builder, report.issues)
  builder.write_string(",\"uncovered\":")
  write_string_array(builder, report.uncovered)
  builder.write_string("}")
  builder.to_string()
}

///|
fn report_json(report : @lib.AuditReport) -> String {
  let builder = StringBuilder()
  builder.write_string("{\"covered\":")
  builder.write_string(report.covered_count.to_string())
  builder.write_string(",\"total\":")
  builder.write_string(report.total_count.to_string())
  builder.write_string(",\"issues\":")
  write_issues_json(builder, report.issues)
  builder.write_string(",\"entries\":[")
  let mut first = true
  for entry in report.entries {
    if !first {
      builder.write_char(',')
    }
    first = false
    builder.write_string("{\"path\":")
    write_json_string(builder, entry.path)
    builder.write_string(",\"owners\":")
    let owners = []
    for owner in entry.owners {
      owners.push(owner.raw)
    }
    write_string_array(builder, owners)
    builder.write_string(",\"pattern\":")
    match entry.matched_pattern {
      Some(pattern) => write_json_string(builder, pattern)
      None => builder.write_string("null")
    }
    builder.write_string(",\"line\":")
    match entry.matched_line {
      Some(line) => builder.write_string(line.to_string())
      None => builder.write_string("null")
    }
    builder.write_string("}")
  }
  builder.write_string("]}")
  builder.to_string()
}

///|
fn write_issues_json(
  builder : StringBuilder,
  issues : Array[@lib.ParseIssue],
) -> Unit {
  builder.write_char('[')
  let mut first = true
  for issue in issues {
    if !first {
      builder.write_char(',')
    }
    first = false
    builder.write_string("{\"line\":")
    builder.write_string(issue.line.to_string())
    builder.write_string(",\"message\":")
    write_json_string(builder, issue.message)
    builder.write_string(",\"source\":")
    write_json_string(builder, issue.source)
    builder.write_char('}')
  }
  builder.write_char(']')
}

///|
fn write_string_array(builder : StringBuilder, values : Array[String]) -> Unit {
  builder.write_char('[')
  let mut first = true
  for value in values {
    if !first {
      builder.write_char(',')
    }
    first = false
    write_json_string(builder, value)
  }
  builder.write_char(']')
}

///|
fn write_json_string(builder : StringBuilder, value : String) -> Unit {
  builder.write_char('"')
  for char in value {
    match char {
      '"' => builder.write_string("\\\"")
      '\\' => builder.write_string("\\\\")
      '\n' => builder.write_string("\\n")
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      _ => builder.write_char(char)
    }
  }
  builder.write_char('"')
}
