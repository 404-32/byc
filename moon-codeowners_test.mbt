///|
test "public API parses rules and resolves owners" {
  let text =
    #|* @global-owner1 @global-owner2
    #|*.js @js-owner # inline comment
    #|*.go docs@example.com
    #|*.txt @octo-org/octocats
  let parsed = @moon-codeowners.Codeowners::parse(text)
  assert_eq(parsed.rule_count(), 4)
  assert_true(parsed.is_valid())
  let owners = parsed.owners_for("src/app.js")
  assert_eq(owners.length(), 1)
  assert_eq(owners[0].raw, "@js-owner")
  assert_true(owners[0].kind is User)
  assert_eq(parsed.owners_for("docs/readme.txt")[0].raw, "@octo-org/octocats")
  assert_eq(parsed.owners_for("main.go")[0].raw, "docs@example.com")
}
