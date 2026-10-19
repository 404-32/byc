///|
fn main {
  let document = @codeowners.Codeowners::parse(
    (
      #|*         @project-owner
      #|/src/     @src-team
      #|*.md      docs@example.com
      #|!ignored  @nobody
    ),
  )
  let paths = ["src/parser.mbt", "docs/guide.md", "build/tool.exe"]
  let report = document.audit(paths)
  println("rules: \{document.rule_count()}")
  println("parse issues: \{document.issues.length()}")
  println(
    "coverage: \{report.covered_count}/\{report.total_count}, uncovered=\{report.uncovered.length()}",
  )
  for entry in report.entries {
    match entry.matched_pattern {
      Some(pattern) =>
        println(
          "\{entry.path} -> \{pattern} (line \{entry.matched_line.unwrap()})",
        )
      None => println("\{entry.path} -> UNCOVERED")
    }
  }
}
