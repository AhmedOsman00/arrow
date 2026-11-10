#!/bin/bash
# Prints a Markdown line-coverage summary for a package's last `swift test --enable-code-coverage` run:
# the total, then each source file in a collapsible table. Test files and dependencies are left out.
#
# Usage: scripts/coverage-summary.sh <package directory> <test bundle name> <title>

set -euo pipefail

PACKAGE="$(cd "$1" && pwd)"
BUNDLE="$2"
TITLE="$3"

xcrun llvm-cov export -summary-only \
  "$PACKAGE/.build/debug/$BUNDLE.xctest/Contents/MacOS/$BUNDLE" \
  -instr-profile "$PACKAGE/.build/debug/codecov/default.profdata" \
  -ignore-filename-regex '/(\.build|Tests)/' \
  | jq -r --arg title "$TITLE" --arg root "$PACKAGE/" '
    def pct: (.covered / (if .count == 0 then 1 else .count end) * 1000 | round / 10 | tostring) + "%";
    .data[0] as $data
    | "### \($title): \($data.totals.lines | pct) of lines covered",
      "",
      "<details><summary>\($data.files | length) files</summary>",
      "",
      "| File | Lines | Covered |",
      "|---|---:|---:|",
      ($data.files | sort_by(.filename)[]
        | "| `\(.filename | ltrimstr($root))` | \(.summary.lines.covered)/\(.summary.lines.count) | \(.summary.lines | pct) |"),
      "",
      "</details>"'
