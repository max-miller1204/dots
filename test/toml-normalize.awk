function fail(message) {
  print "invalid TOML: " message > "/dev/stderr"
  exit 1
}

function trim(value) {
  sub(/^[[:space:]]+/, "", value)
  sub(/[[:space:]]+$/, "", value)
  return value
}

function uncomment(value, position, character, quoted, escaped, result) {
  result = ""
  for (position = 1; position <= length(value); position++) {
    character = substr(value, position, 1)
    if (quoted) {
      result = result character
      if (escaped) {
        escaped = 0
      } else if (character == "\\") {
        escaped = 1
      } else if (character == "\"") {
        quoted = 0
      }
    } else if (character == "#") {
      break
    } else {
      result = result character
      if (character == "\"") quoted = 1
    }
  }
  if (quoted || escaped) fail("unterminated string on line " NR)
  return result
}

function assignment_separator(value, position, character, quoted, escaped) {
  for (position = 1; position <= length(value); position++) {
    character = substr(value, position, 1)
    if (quoted) {
      if (escaped) {
        escaped = 0
      } else if (character == "\\") {
        escaped = 1
      } else if (character == "\"") {
        quoted = 0
      }
    } else if (character == "\"") {
      quoted = 1
    } else if (character == "=") {
      return position
    }
  }
  return 0
}

function normalize_key(value) {
  value = trim(value)
  if (value ~ /^[A-Za-z0-9_-]+$/) return value
  if (value ~ /^"[^"\\]+"$/) return substr(value, 2, length(value) - 2)
  fail("unsupported key on line " NR)
}

function define_table(path, parent) {
  if (path in nodes && nodes[path] != "table") {
    fail("table conflicts with key " path " on line " NR)
  }
  if (path in explicit_tables) fail("duplicate table " path " on line " NR)
  parent = path
  while (sub(/\.[^.]+$/, "", parent)) {
    if (parent in nodes && nodes[parent] != "table") {
      fail("table conflicts with parent key " parent " on line " NR)
    }
    nodes[parent] = "table"
  }
  nodes[path] = "table"
  explicit_tables[path] = 1
}

function record(type, path, value, inline_parent, parent, existing) {
  if (path in nodes) fail("duplicate or conflicting key " path " on line " NR)
  parent = path
  while (sub(/\.[^.]+$/, "", parent)) {
    if (parent in nodes && nodes[parent] != "table" && parent != inline_parent) {
      fail("key conflicts with parent value " parent " on line " NR)
    }
  }
  for (existing in nodes) {
    if (index(existing, path ".") == 1) {
      fail("key conflicts with child path " existing " on line " NR)
    }
  }
  nodes[path] = type
  print type "\t" path "\t" value
}

function normalize_scalar(path, value, inline_parent) {
  value = trim(value)
  if (value ~ /^"[^"\\]*"$/) {
    record("basic-string", path, substr(value, 2, length(value) - 2), inline_parent)
  } else if (value == "true" || value == "false") {
    record("boolean", path, value, inline_parent)
  } else {
    fail("unsupported value for " path " on line " NR)
  }
}

function normalize_inline(path, value, body, count, parts, position, separator, key, item_path) {
  body = trim(substr(value, 2, length(value) - 2))
  record("inline-table", path, "")
  if (body == "") return
  count = split(body, parts, /,[[:space:]]*/)
  for (position = 1; position <= count; position++) {
    separator = assignment_separator(parts[position])
    if (!separator) fail("invalid inline table on line " NR)
    key = normalize_key(substr(parts[position], 1, separator - 1))
    item_path = path "." key
    normalize_scalar(item_path, substr(parts[position], separator + 1), path)
  }
}

{
  line = trim(uncomment($0))
  if (line == "") next
  if (line ~ /^\[[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*\]$/) {
    table = substr(line, 2, length(line) - 2)
    define_table(table)
    next
  }
  separator = assignment_separator(line)
  if (!separator) fail("invalid assignment on line " NR)
  key = normalize_key(substr(line, 1, separator - 1))
  path = table == "" ? key : table "." key
  value = trim(substr(line, separator + 1))
  if (value ~ /^\{.*\}$/) {
    normalize_inline(path, value)
  } else {
    normalize_scalar(path, value)
  }
}
