///|
/// Parse CODEOWNERS text. Invalid lines are skipped and collected in
/// `issues`, mirroring GitHub's behavior.
pub fn Codeowners::parse(text : String) -> Self {
  let rules : Array[Rule] = []
  let issues : Array[ParseIssue] = []
  let mut line_number = 0
  for line_view in text.split("\n") {
    line_number = line_number + 1
    let original = line_view.trim().to_owned()
    if original.is_empty() {
      continue
    }
    let line = remove_comment(original)
    let tokens = split_whitespace(line)
    if tokens.is_empty() {
      continue
    }
    let pattern = tokens[0]
    let issue = match validate_pattern(pattern) {
      Some(message) => Some(message)
      None => None
    }
    if issue is Some(message) {
      issues.push({ line: line_number, source: original, message, })
      continue
    }
    if tokens.length() < 2 {
      issues.push({
        line: line_number,
        source: original,
        message: "pattern has no owners",
      })
      continue
    }
    let owners = []
    let mut valid = true
    for index in 1..<tokens.length() {
      match parse_owner(tokens[index]) {
        Some(owner) => owners.push(owner)
        None => valid = false
      }
    }
    if !valid || owners.is_empty() {
      issues.push({
        line: line_number,
        source: original,
        message: "owner must be @user, @org/team, or an email address",
      })
      continue
    }
    rules.push({ pattern, owners, line: line_number, })
  }
  { rules, issues, }
}

///|
fn validate_pattern(pattern : String) -> String? {
  if pattern == "/" {
    return Some("pattern must identify a file or directory")
  }
  if pattern.has_prefix("!") {
    return Some("negated patterns are not supported by CODEOWNERS")
  }
  if pattern.contains("[") || pattern.contains("]") {
    return Some("character classes are not supported by CODEOWNERS")
  }
  if pattern.contains("\\") {
    return Some("backslash escapes are not supported by CODEOWNERS")
  }
  None
}

///|
fn parse_owner(token : String) -> Owner? {
  if token.length() < 2 {
    return None
  }
  if token.has_prefix("@") {
    let name = token.exact_view(start=1).to_owned()
    if name.is_empty() {
      return None
    }
    if name.contains("/") {
      let pieces = name.split("/").to_array()
      if pieces.length() != 2 || pieces[0].is_empty() || pieces[1].is_empty() {
        return None
      }
      return Some({ raw: token, kind: Team, })
    }
    return Some({ raw: token, kind: User, })
  }
  let at = token.find("@")
  if at is Some(index) &&
    count_char(token, '@') == 1 &&
    index > 0 &&
    index + 1 < token.length() &&
    token.exact_view(start=index + 1).contains(".") {
    return Some({ raw: token, kind: Email, })
  }
  None
}

///|
fn count_char(text : String, expected : Char) -> Int32 {
  let mut count = 0
  for char in text {
    if char == expected {
      count = count + 1
    }
  }
  count
}

///|
fn remove_comment(line : String) -> String {
  let chars = line.to_array()
  let builder = StringBuilder()
  for char in chars {
    if char == '#' {
      break
    }
    builder.write_char(char)
  }
  builder.to_string().trim().to_owned()
}

///|
fn split_whitespace(line : String) -> Array[String] {
  let tokens = []
  let builder = StringBuilder()
  let mut in_token = false
  for char in line {
    if is_whitespace(char) {
      if in_token {
        tokens.push(builder.to_string())
        builder.reset()
        in_token = false
      }
    } else {
      builder.write_char(char)
      in_token = true
    }
  }
  if in_token {
    tokens.push(builder.to_string())
  }
  tokens
}

///|
fn is_whitespace(char : Char) -> Bool {
  char == ' ' || char == '\t' || char == '\r' || char == '\n'
}
