///|
/// The kind of owner accepted by a CODEOWNERS file.
pub(all) enum OwnerKind {
  User
  Team
  Email
}

///|
/// A single CODEOWNERS owner token.
pub(all) struct Owner {
  raw : String
  kind : OwnerKind
}

///|
/// A parsed CODEOWNERS rule.
pub(all) struct Rule {
  pattern : String
  owners : Array[Owner]
  line : Int32
}

///|
/// A recoverable parsing problem. GitHub skips invalid CODEOWNERS lines, so the
/// parser keeps valid rules and reports invalid lines separately.
pub(all) struct ParseIssue {
  line : Int32
  source : String
  message : String
}

///|
/// A parsed CODEOWNERS document.
pub(all) struct Codeowners {
  rules : Array[Rule]
  issues : Array[ParseIssue]
}

///|
pub fn Codeowners::is_valid(self : Self) -> Bool {
  self.issues.is_empty()
}

///|
pub fn Codeowners::rule_count(self : Self) -> Int32 {
  self.rules.length()
}

///|
/// Return the last matching rule. CODEOWNERS deliberately gives the last
/// matching rule precedence.
pub fn Codeowners::find_rule(self : Self, path : String) -> Rule? {
  let normalized = normalize_path(path)
  if normalized.is_empty() {
    return None
  }
  let mut matched = None
  for rule in self.rules {
    if rule.matches(normalized) {
      matched = Some(rule)
    }
  }
  matched
}

///|
/// Return the effective owners for a repository path.
pub fn Codeowners::owners_for(self : Self, path : String) -> Array[Owner] {
  match self.find_rule(path) {
    Some(rule) => clone_owners(rule.owners)
    None => []
  }
}

///|
fn clone_owners(owners : Array[Owner]) -> Array[Owner] {
  let result = []
  for owner in owners {
    result.push(owner)
  }
  result
}
