#!/bin/bash
# Compiles the Foundation-only files in Holocron/Core with the tests in Tests/Core and runs them.
# The tests only touch a temporary folder, never the real data folder.
#
#   scripts/test-core.sh

set -euo pipefail
cd "$(dirname "$0")/.."

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

swiftc -O -o "$OUT/core-tests" \
  Holocron/Core/CSV.swift \
  Holocron/Core/Schema.swift \
  Holocron/Core/DataFolder.swift \
  Holocron/Core/WorkFiles.swift \
  Holocron/Core/StartOver.swift \
  Holocron/Core/RowMerge.swift \
  Holocron/Core/MergedSave.swift \
  Holocron/Core/SchemaVersion.swift \
  Holocron/Core/Markbook.swift \
  Holocron/Core/ReportBoard.swift \
  Holocron/Core/Grouping.swift \
  Holocron/Core/Tone.swift \
  Holocron/Core/SubjectColours.swift \
  Tests/Core/main.swift
"$OUT/core-tests"
