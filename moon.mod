// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "404-32/moon-codeowners"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/404-32/byc"

license = "Apache-2.0"

keywords = [ "codeowners", "monorepo", "developer-tools", "ci", "github" ]

preferred_target = "wasm"

description = "Deterministic CODEOWNERS parser, matcher, and coverage auditor for MoonBit."

import {
  "moonbitlang/async@0.22.5",
}
