///|
test "last matching rule wins" {
  let parsed = Codeowners::parse(
    (
      #|* @all
      #|/src @src
      #|/src/http @http
    ),
  )
  assert_eq(parsed.owners_for("src/http/client.mbt")[0].raw, "@http")
  assert_eq(parsed.owners_for("src/core/client.mbt")[0].raw, "@src")
  assert_eq(parsed.owners_for("README.md")[0].raw, "@all")
}

///|
test "github pattern examples" {
  let parsed = Codeowners::parse(
    (
      #|*.js @js
      #|/build/logs/ @build
      #|docs/* @docs
      #|apps/ @apps
      #|**/*.mbt @moonbit
    ),
  )
  assert_eq(parsed.owners_for("web/a.js")[0].raw, "@js")
  assert_eq(parsed.owners_for("build/logs/run.txt")[0].raw, "@build")
  assert_eq(parsed.owners_for("nested/build/logs/run.txt").length(), 0)
  assert_eq(parsed.owners_for("docs/getting.md")[0].raw, "@docs")
  assert_eq(parsed.owners_for("docs/build/app.md").length(), 0)
  assert_eq(parsed.owners_for("src/apps/tool/main.txt")[0].raw, "@apps")
  assert_eq(parsed.owners_for("src/lib/main.mbt")[0].raw, "@moonbit")
}

///|
test "single star and question mark stay inside one segment" {
  let parsed = Codeowners::parse(
    (
      #|/src/*.mbt @single
      #|file?.txt @question
    ),
  )
  assert_eq(parsed.owners_for("src/main.mbt")[0].raw, "@single")
  assert_eq(parsed.owners_for("src/nested/main.mbt").length(), 0)
  assert_eq(parsed.owners_for("file1.txt")[0].raw, "@question")
  assert_eq(parsed.owners_for("file10.txt").length(), 0)
}

///|
test "double star matches zero or more directories" {
  let parsed = Codeowners::parse(
    (
      #|/src/**/test.mbt @tests
      #|/docs/** @docs
    ),
  )
  assert_eq(parsed.owners_for("src/test.mbt")[0].raw, "@tests")
  assert_eq(parsed.owners_for("src/a/b/test.mbt")[0].raw, "@tests")
  assert_eq(parsed.owners_for("src/a/main.mbt").length(), 0)
  assert_eq(parsed.owners_for("docs/guide.md")[0].raw, "@docs")
  assert_eq(parsed.owners_for("docs/a/b.md")[0].raw, "@docs")
}

///|
test "owner kinds are classified" {
  let parsed = Codeowners::parse(
    (
      #|* @user @org/team user@example.com
    ),
  )
  let owners = parsed.owners_for("README.md")
  assert_eq(owners.length(), 3)
  assert_true(owners[0].kind is User)
  assert_true(owners[1].kind is Team)
  assert_true(owners[2].kind is Email)
  assert_eq(owners[2].raw, "user@example.com")
}

///|
test "path normalization and case sensitivity" {
  let parsed = Codeowners::parse(
    (
      #|/src/*.mbt @src
      #|/README.md @docs
    ),
  )
  assert_eq(parsed.owners_for("src\\lib.mbt")[0].raw, "@src")
  assert_eq(parsed.owners_for("./src/lib.mbt")[0].raw, "@src")
  assert_eq(parsed.owners_for("src/README.md").length(), 0)
  assert_eq(parsed.owners_for("readme.md").length(), 0)
}

///|
test "invalid lines are skipped and reported" {
  let parsed = Codeowners::parse(
    (
      #|!ignored.txt @owner
      #|no-owners
      #|[ab].txt @owner
      #|valid.txt @owner
    ),
  )
  assert_eq(parsed.rule_count(), 1)
  assert_eq(parsed.issues.length(), 3)
  assert_eq(parsed.issues[0].line, 1)
  assert_eq(parsed.owners_for("valid.txt")[0].raw, "@owner")
}

///|
test "parser edge cases produce bounded diagnostics" {
  let parsed = Codeowners::parse(
    (
      #|
      #|# comment only
      #|/ @owner
      #|a.txt @
      #|b.txt plainword
      #|c.txt @/team
      #|d.txt @org/team/extra
      #|e.txt nodot@example
      #|f.txt a@b@c.com
      #|bad\path @owner
      #|valid.txt @owner
    ),
  )
  assert_eq(parsed.rule_count(), 1)
  assert_eq(parsed.issues.length(), 8)
  assert_true(parsed.find_rule("") is None)
}

///|
test "root-relative directory pattern without leading slash" {
  let parsed = Codeowners::parse(
    (
      #|src/http @http
    ),
  )
  assert_eq(parsed.owners_for("src/http/client.mbt")[0].raw, "@http")
  assert_eq(parsed.owners_for("src/main.mbt").length(), 0)
}

///|
test "duplicate and directory rules preserve source lines" {
  let parsed = Codeowners::parse(
    (
      #|/src/ @first
      #|/src/ @second
    ),
  )
  let rule = parsed.find_rule("src/nested/main.mbt").unwrap()
  assert_eq(rule.owners[0].raw, "@second")
  assert_eq(rule.line, 2)
}

///|
test "coverage audit reports uncovered paths" {
  let parsed = Codeowners::parse(
    (
      #|/src/ @src
      #|*.md @docs
    ),
  )
  let report = parsed.audit(["src/main.mbt", "README.md", "build/tool.exe"])
  assert_eq(report.total_count, 3)
  assert_eq(report.covered_count, 2)
  assert_eq(report.uncovered.length(), 1)
  assert_eq(report.uncovered[0], "build/tool.exe")
  assert_eq(report.entries[1].matched_pattern.unwrap(), "*.md")
  assert_eq(report.entries[1].matched_line.unwrap(), 2)
}

///|
test "coverage audit carries parser issues" {
  let parsed = Codeowners::parse(
    (
      #|!invalid @owner
      #|* @owner
    ),
  )
  let report = parsed.audit(["README.md"])
  assert_eq(report.issues.length(), 1)
  assert_eq(report.covered_count, 1)
}
