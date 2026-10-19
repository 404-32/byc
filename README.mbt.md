# moon-codeowners

[![CI](https://github.com/404-32/byc/actions/workflows/ci.yml/badge.svg)](https://github.com/404-32/byc/actions/workflows/ci.yml)

Deterministic CODEOWNERS parsing, matching, and coverage auditing for MoonBit.

`moon-codeowners` is a focused developer tool for monorepos and CI. It implements
GitHub's CODEOWNERS precedence model, explains which rule selected an owner, and
audits changed-file lists for missing ownership. The core library is pure
MoonBit and works without network access.

## Why this project

Generic glob libraries answer "does this path match this pattern?". CODEOWNERS
requires more:

- the last matching rule wins;
- rules can assign users, teams, or email addresses;
- paths are case-sensitive;
- a directory rule owns all descendants;
- invalid lines are skipped and should be reported;
- CI needs to know whether every changed file has an owner.

The package separates those policy semantics from generic pattern matching.

## Features

- Parse users, teams, and email owners.
- Support `*`, `**`, and `?` path patterns.
- Support root-anchored and unanchored patterns.
- Apply GitHub's last-match-wins rule.
- Explain the effective owner, matched pattern, and source line.
- Audit one or many repository paths.
- Report uncovered files and invalid CODEOWNERS lines.
- Emit human-readable or JSON output from the CLI.
- Run on the MoonBit Wasm target with no native dependency.

## Quick start

Build and test from source:

```bash
git clone https://github.com/404-32/byc.git
cd byc
moon test --target wasm
```

Explain an owner:

```bash
moon run cmd/main -- explain .github/CODEOWNERS src/parser.mbt
```

Check a changed-file list:

```bash
moon run cmd/main -- check .github/CODEOWNERS examples/changed-files.txt
```

Produce JSON for CI:

```bash
moon run cmd/main -- coverage .github/CODEOWNERS examples/changed-files.txt --json
```

Run the standalone library example:

```bash
moon run examples/basic
```

## Library API

```moonbit nocheck
///|
let document = @codeowners.Codeowners::parse(
  (
    #|*       @global-owner
    #|/src/   @src-team
    #|*.md    docs@example.com
  ),
)

///|
let rule = document.find_rule("src/http/client.mbt")

///|
let owners = document.owners_for("src/http/client.mbt")

///|
let report = document.audit(["src/http/client.mbt", "build/tool.exe"])
```

`owners_for` returns the effective owners. `find_rule` additionally exposes the
matched pattern and line number. `audit` returns one result per input path,
including uncovered paths and any parser diagnostics.

## CLI

```text
moon-codeowners check <CODEOWNERS> [paths-file] [--json]
moon-codeowners owners <CODEOWNERS> <repo-path>
moon-codeowners explain <CODEOWNERS> <repo-path>
moon-codeowners coverage <CODEOWNERS> <paths-file> [--json]
```

A paths file contains one repository-relative path per line. `check` exits with
an error when parsing or coverage checks fail, making it suitable for CI.

## Supported CODEOWNERS semantics

- The last matching rule takes precedence.
- `*` and `?` do not cross `/`.
- `**` may cross directory boundaries.
- A leading `/` anchors a pattern to the repository root.
- A trailing `/` marks a directory rule and covers its descendants.
- A pattern containing no `/` matches path segments at any depth.
- Paths are compared case-sensitively.
- Windows-style path separators are normalized before matching.

Following GitHub's documented limitations, these forms are rejected and
reported as parse issues:

- `!` negation;
- `[abc]` character classes;
- backslash escaping.

Owner existence, team membership, and repository permissions are intentionally
outside this package. Those checks require GitHub API credentials and introduce
network-dependent policy. `moon-codeowners` remains an offline, deterministic
core that can be used by CI, review bots, and editor tooling.

## Use cases

1. CI gate: every changed file must resolve to an owner before a pull request is
   accepted.
2. Review routing: a bot uses the matched user or team to request reviewers.
3. Developer tooling: an editor command explains why a file is assigned to a
   particular owner.

## Development

```bash
moon check --target wasm --deny-warn
moon test --target wasm --deny-warn
moon fmt --check
moon run cmd/main -- check .github/CODEOWNERS examples/changed-files.txt
```

License: Apache-2.0.
