# Shared frontmatter helper; source this file, don't run it.

# Prints the value of a top-level frontmatter key. Handles plain, quoted and
# block-scalar (| or >) values; block scalars are joined with spaces.
frontmatter_value() {
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 { next }
    /^---[[:space:]]*$/ { exit }
    block {
      if ($0 ~ /^[[:space:]]+[^[:space:]]/ || $0 ~ /^[[:space:]]*$/) {
        line = $0; sub(/^[[:space:]]+/, "", line)
        if (line != "") value = value (value == "" ? "" : " ") line
        next
      }
      exit
    }
    $0 ~ "^" key ":" {
      value = $0
      sub("^" key ":[[:space:]]*", "", value)
      sub(/[[:space:]]+$/, "", value)
      if (value ~ /^[|>][-+]?$/) { value = ""; block = 1; next }
      if (value ~ /^".*"$/ || value ~ /^'\''.*'\''$/) value = substr(value, 2, length(value) - 2)
      exit
    }
    END { print value }
  ' "$file"
}
