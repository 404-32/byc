///|
/// The ownership result for one repository path.
pub(all) struct AuditEntry {
  path : String
  owners : Array[Owner]
  matched_pattern : String?
  matched_line : Int32?
}

///|
/// A complete coverage audit.
pub(all) struct AuditReport {
  entries : Array[AuditEntry]
  uncovered : Array[String]
  issues : Array[ParseIssue]
  covered_count : Int32
  total_count : Int32
}

///|
pub fn Codeowners::audit(self : Self, paths : Array[String]) -> AuditReport {
  let entries : Array[AuditEntry] = []
  let uncovered : Array[String] = []
  let mut covered_count = 0
  for path in paths {
    match self.find_rule(path) {
      Some(rule) => {
        entries.push({
          path,
          owners: clone_owners(rule.owners),
          matched_pattern: Some(rule.pattern),
          matched_line: Some(rule.line),
        })
        covered_count = covered_count + 1
      }
      None => {
        entries.push({
          path,
          owners: [],
          matched_pattern: None,
          matched_line: None,
        })
        uncovered.push(path)
      }
    }
  }
  {
    entries,
    uncovered,
    issues: clone_issues(self.issues),
    covered_count,
    total_count: paths.length(),
  }
}

///|
fn clone_issues(issues : Array[ParseIssue]) -> Array[ParseIssue] {
  let result = []
  for issue in issues {
    result.push(issue)
  }
  result
}
