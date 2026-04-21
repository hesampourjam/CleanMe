#!/usr/bin/env bash
# Generate CleanMe.xcodeproj from project.yml.
# Installs xcodegen via Homebrew if missing.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to install xcodegen. Install it from https://brew.sh then rerun." >&2
    exit 1
  fi
  echo "Installing xcodegen via Homebrew…"
  brew install xcodegen
fi

echo "Generating CleanMe.xcodeproj from project.yml…"
xcodegen generate --spec project.yml

echo
echo "Done. Open the project with:"
echo "  open CleanMe.xcodeproj"
