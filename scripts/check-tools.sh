#!/usr/bin/env sh
set -eu

. ./scripts/load-env.sh

required_tools="docker kind kubectl helm npm curl"
missing_count=0

for tool in $required_tools; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf "ok: %s\n" "$tool"
  else
    printf "missing: %s\n" "$tool" >&2
    missing_count=$((missing_count + 1))
  fi
done

if [ "$missing_count" -gt 0 ]; then
  printf "Instale as ferramentas ausentes antes de continuar.\n" >&2
  exit 1
fi
