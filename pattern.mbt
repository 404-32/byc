///|
priv enum GlobToken {
  Literal(Char)
  Any
  Star
  DoubleStar
  DoubleStarSlash
}

///|
/// Normalize repository paths accepted from Windows and Unix callers.
pub fn normalize_path(path : String) -> String {
  let builder = StringBuilder()
  let mut previous_slash = true
  for char in path {
    let normalized = if char == '\\' { '/' } else { char }
    if normalized == '/' {
      if !previous_slash {
        builder.write_char('/')
      }
      previous_slash = true
    } else {
      builder.write_char(normalized)
      previous_slash = false
    }
  }
  let raw = builder.to_string()
  let parts = []
  for part in raw.split("/") {
    if !part.is_empty() && part != "." {
      parts.push(part.to_owned())
    }
  }
  parts.join("/")
}

///|
fn Rule::matches(self : Rule, normalized_path : String) -> Bool {
  let anchored = self.pattern.has_prefix("/")
  let directory = self.pattern.has_suffix("/")
  let mut core = self.pattern
  if anchored {
    core = core.exact_view(start=1).to_owned()
  }
  if directory {
    core = core.exact_view(end=core.length() - 1).to_owned()
  }
  if core.is_empty() {
    return false
  }
  let has_slash = core.contains("/")
  let has_magic = core.contains("*") || core.contains("?")
  let segments = split_segments(normalized_path)
  if anchored {
    if !has_slash {
      return !segments.is_empty() && match_glob(core, segments[0])
    }
    if directory || !has_magic {
      return match_directory_prefixes(core, normalized_path, 0)
    }
    return match_glob(core, normalized_path)
  }
  if !has_slash {
    for segment in segments {
      if match_glob(core, segment) {
        return true
      }
    }
    return false
  }
  if directory || !has_magic {
    return match_directory_prefixes(core, normalized_path, 0)
  }
  match_glob(core, normalized_path)
}

///|
fn split_segments(path : String) -> Array[String] {
  let segments = []
  for segment in path.split("/") {
    segments.push(segment.to_owned())
  }
  segments
}

///|
fn match_directory_prefixes(
  pattern : String,
  path : String,
  start : Int32,
) -> Bool {
  let chars = path.to_array()
  let mut end = start + 1
  while end <= chars.length() {
    if end == chars.length() || chars[end] == '/' {
      if match_glob(pattern, chars_to_string(chars, start, end)) {
        return true
      }
    }
    end = end + 1
  }
  false
}

///|
fn chars_to_string(chars : Array[Char], start : Int32, end : Int32) -> String {
  let builder = StringBuilder()
  let mut index = start
  while index < end {
    builder.write_char(chars[index])
    index = index + 1
  }
  builder.to_string()
}

///|
fn tokenize_glob(pattern : String) -> Array[GlobToken] {
  let chars = pattern.to_array()
  let tokens = []
  let mut index = 0
  while index < chars.length() {
    let char = chars[index]
    if char == '*' {
      if index + 1 < chars.length() && chars[index + 1] == '*' {
        if index + 2 < chars.length() && chars[index + 2] == '/' {
          tokens.push(DoubleStarSlash)
          index = index + 3
        } else {
          tokens.push(DoubleStar)
          index = index + 2
          while index < chars.length() && chars[index] == '*' {
            index = index + 1
          }
        }
      } else {
        tokens.push(Star)
        index = index + 1
        while index < chars.length() && chars[index] == '*' {
          index = index + 1
        }
      }
    } else if char == '?' {
      tokens.push(Any)
      index = index + 1
    } else {
      tokens.push(Literal(char))
      index = index + 1
    }
  }
  tokens
}

///|
fn match_glob(pattern : String, path : String) -> Bool {
  let tokens = tokenize_glob(pattern)
  let chars = path.to_array()
  let rows = Array::makei(tokens.length() + 1, _ => {
    Array::make(chars.length() + 1, false)
  })
  rows[0][0] = true
  for token_index in 1..<=tokens.length() {
    match tokens[token_index - 1] {
      Star | DoubleStar | DoubleStarSlash =>
        rows[token_index][0] = rows[token_index - 1][0]
      _ => ()
    }
  }
  for token_index in 1..<=tokens.length() {
    let token = tokens[token_index - 1]
    for path_index in 1..<=chars.length() {
      rows[token_index][path_index] = match token {
        Literal(expected) =>
          rows[token_index - 1][path_index - 1] &&
          expected == chars[path_index - 1]
        Any =>
          rows[token_index - 1][path_index - 1] && chars[path_index - 1] != '/'
        Star =>
          rows[token_index - 1][path_index] ||
          (chars[path_index - 1] != '/' && rows[token_index][path_index - 1])
        DoubleStar =>
          rows[token_index - 1][path_index] || rows[token_index][path_index - 1]
        DoubleStarSlash => {
          let mut value = rows[token_index - 1][path_index]
          if chars[path_index - 1] == '/' {
            let mut start = 0
            while start <= path_index && !value {
              if rows[token_index - 1][start] {
                value = true
              }
              start = start + 1
            }
          }
          value
        }
      }
    }
  }
  rows[tokens.length()][chars.length()]
}
