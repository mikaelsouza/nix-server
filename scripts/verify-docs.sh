#!/usr/bin/env bash
# Drift guards for the single-source-of-truth README.
# Referenced from README §7 (Validation Workflow) and §13 (Agent Checklist).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# --- (a) Tree completeness ---------------------------------------------
# Every .nix under hosts/ and modules/ must appear in the §2 layout tree.
# CONSTRAINT: the §2 tree MUST stay the first ```text fence in README.md, and
# entries MUST use the box-drawing format (├──/└── at 4-space depth increments).
actual="$(find hosts modules -name '*.nix' | sort)"
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
    unset "dirs[$((depth + 1))]"           # drop deeper stale entries
  else
    base=""
    for ((d = 0; d <= depth; d++)); do
      [[ -n "${dirs[$d]:-}" ]] && base="${base}${dirs[$d]}/"
    done
    paths+="${base}${name}"$'\n'
  fi
done <<< "$tree_block"
declared="$(printf '%s\n' "$paths" | grep '\.nix$' | sort -u)"
missing="$(comm -23 <(printf '%s\n' "$actual") <(printf '%s\n' "$declared"))"
if [[ -n "$missing" ]]; then
  echo "FAIL: .nix files missing from README §2 tree:" >&2
  printf '%s\n' "$missing" >&2
  exit 1
fi
count="$(printf '%s\n' "$actual" | wc -l | tr -d ' ')"
echo "OK: README §2 tree covers all $count .nix files under hosts/ and modules/."

# --- (b) Direct flake inputs ---------------------------------------------
# README must state the count phrase and name all 5 direct inputs.
grep -q '5 direct inputs' README.md \
  || { echo "FAIL: README must state '5 direct inputs' (see §0)." >&2; exit 1; }
for input in nixpkgs nixpkgs-unstable nix-darwin nix-homebrew comin; do
  grep -qw "$input" README.md \
    || { echo "FAIL: README does not name direct input '$input'." >&2; exit 1; }
done
echo "OK: README names all 5 direct flake inputs."

# --- (c) Internal anchor resolution --------------------------------------
# Every '](#slug)' link must resolve to a README heading slug (GitHub rules).
headings="$(grep -E '^#{2,4} ' README.md \
  | sed -E 's/^#+ +//; s/`//g; s/[^A-Za-z0-9 ]//g; s/ +/ /g; s/ /-/g; s/--+/-/g; s/^-+|-+$//g' \
  | tr '[:upper:]' '[:lower:]')"
fail=0
while IFS= read -r anchor; do
  [[ -z "$anchor" ]] && continue
  if ! grep -qx "$anchor" <<< "$headings"; then
    echo "FAIL: internal link '#$anchor' does not resolve to a README heading." >&2
    fail=1
  fi
done < <(grep -oE '\]\(#[A-Za-z0-9-]+\)' README.md | sed -E 's/^\]\(#//; s/\)$//' | sort -u)
[[ $fail -eq 0 ]] || exit 1
echo "OK: all internal '#anchor' links resolve to README headings."
