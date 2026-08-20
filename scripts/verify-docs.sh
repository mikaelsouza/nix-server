#!/usr/bin/env bash
# Drift guards for the single-source-of-truth README.
# Referenced from README §7 (Validation Workflow) and §13 (Agent Checklist).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# --- (a) Tree completeness ---------------------------------------------
# Every .nix under hosts/ and modules/ must appear in the §2 layout tree, and
# every .nix the tree declares under those dirs must actually exist.
# CONSTRAINT: the §2 tree MUST stay the first ```text fence in README.md, and
# entries MUST use the box-drawing format (├──/└── at 4-space depth increments).
[[ -f README.md ]] || { echo "FAIL: README.md must exist." >&2; exit 1; }
[[ -d hosts && -d modules ]] \
  || { echo "FAIL: hosts/ and modules/ must exist." >&2; exit 1; }
actual="$(find hosts modules -name '*.nix' 2>/dev/null | sort || true)"
tree_block="$(awk '/^```text$/{f=1; next} /^```$/{if (f) exit} f' README.md)"

# Reconstruct paths from the tree: depth = column of the first box glyph / 4.
declare -a dirs=()
paths=""
while IFS= read -r line; do
  line="${line%%#*}"                       # strip trailing comment
  line="$(printf '%s' "$line" | sed 's/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue
  glyph_col="$(printf '%s' "$line" | awk '{ i=index($0,"├"); j=index($0,"└"); if (i==0) i=j; print i }')"
  [[ "$glyph_col" == "0" ]] && continue    # root line (e.g. "nix-server/")
  depth=$(( (glyph_col - 1) / 4 ))
  name="$(printf '%s' "$line" | sed -E 's/^.*[├└]── +//')"
  if [[ "$name" == */ ]]; then
    dirs["$depth"]="${name%/}"             # directory: record at this depth
    for ((d = depth + 1; d <= depth + 32; d++)); do
      unset "dirs[$d]"                     # drop ALL deeper stale entries
    done
  else
    for ((d = depth; d <= depth + 32; d++)); do
      unset "dirs[$d]"                     # a file has no children: clear this depth too
    done
    base=""
    for ((d = 0; d < depth; d++)); do
      [[ -n "${dirs[$d]:-}" ]] && base="${base}${dirs[$d]}/"
    done
    paths+="${base}${name}"$'\n'
  fi
done <<< "$tree_block"
declared="$(printf '%s\n' "$paths" | grep '\.nix$' | sort -u || true)"
missing="$(comm -23 <(printf '%s\n' "$actual") <(printf '%s\n' "$declared"))"
if [[ -n "$missing" ]]; then
  echo "FAIL: .nix files missing from README §2 tree:" >&2
  printf '%s\n' "$missing" >&2
  exit 1
fi
extra="$(comm -13 <(printf '%s\n' "$actual") \
  <(printf '%s\n' "$declared" | grep -E '^(hosts|modules)/' | sort -u))"
if [[ -n "$extra" ]]; then
  echo "FAIL: README §2 tree lists .nix files that do not exist:" >&2
  printf '%s\n' "$extra" >&2
  exit 1
fi
count="$(printf '%s\n' "$actual" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "OK: README §2 tree matches all $count .nix files under hosts/ and modules/ (no missing, no extra)."

# --- (b) Direct flake inputs ---------------------------------------------
# README must state the count phrase, name every input flake.nix declares,
# and flake.nix must declare exactly the inputs README names.
grep -q '5 direct inputs' README.md \
  || { echo "FAIL: README must state '5 direct inputs' (see §0)." >&2; exit 1; }
flake_inputs="$(sed -n '/^  inputs = {/,/^  };$/p' flake.nix \
  | grep -oE '^    [a-zA-Z0-9_-]+' | tr -d ' ' | sort -u || true)"
expected_inputs="$(printf '%s\n' nixpkgs nixpkgs-unstable nix-darwin nix-homebrew comin | sort -u)"
if [[ "$flake_inputs" != "$expected_inputs" ]]; then
  echo "FAIL: flake.nix inputs ($(printf '%s ' $flake_inputs)) != expected 5 ($(printf '%s ' $expected_inputs))." >&2
  exit 1
fi
for input in $flake_inputs; do
  # Match the standalone backticked token (e.g. `nixpkgs`) so `nixpkgs`
  # cannot be satisfied by `nixpkgs-unstable`.
  grep -qF "\`$input\`" README.md \
    || { echo "FAIL: README does not name direct input '$input'." >&2; exit 1; }
done
echo "OK: README names all 5 direct flake inputs (matches flake.nix)."

# --- (c) Internal anchor resolution --------------------------------------
# Every '](#slug)' link must resolve to a README heading slug (GitHub rules).
headings="$(grep -E '^#{2,4} ' README.md \
  | sed -E 's/^#+ +//; s/`//g; s/[^A-Za-z0-9 _-]//g; s/ +/ /g; s/ /-/g' \
  | tr '[:upper:]' '[:lower:]' || true)"
fail=0
while IFS= read -r anchor; do
  [[ -z "$anchor" ]] && continue
  if ! grep -qx "$anchor" <<< "$headings"; then
    echo "FAIL: internal link '#$anchor' does not resolve to a README heading." >&2
    fail=1
  fi
done < <(grep -oE '\]\(#[A-Za-z0-9_-]+\)' README.md | sed -E 's/^\]\(#//; s/\)$//' | sort -u)
[[ $fail -eq 0 ]] || exit 1
echo "OK: all internal '#anchor' links resolve to README headings."
