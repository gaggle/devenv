#!/usr/bin/env bash
# repro — enter one devenv project from N shells at once, against a cold
# .devenv, and report which entries survived.
#
# Two is the case worth running: it fails every time here, and it is what a
# process supervisor does when a project declares two processes.
#
# Usage: ./repro.sh [N]   (default 2)
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

n="${1:-2}"
logs=()

rm -rf .devenv

echo "cold .devenv — entering $n shells at once"

pids=()
for _ in $(seq 1 "$n"); do
  log="$(mktemp)"
  logs+=("$log")
  devenv shell -q -- true >"$log" 2>&1 &
  pids+=("$!")
done

failed=0
for i in $(seq 1 "$n"); do
  if wait "${pids[$((i - 1))]}"; then
    status=0
  else
    status=$?
    failed=$((failed + 1))
  fi
  printf '  shell %-3d exit=%s\n' "$i" "$status"
done

echo
for i in $(seq 1 "$n"); do
  log="${logs[$((i - 1))]}"
  if [ -s "$log" ]; then
    echo "── shell $i ──"
    cat "$log"
  fi
done
rm -f "${logs[@]}"

if [ "$failed" -gt 0 ]; then
  echo "FAIL: $failed of $n entries died; every entry should succeed"
  exit 1
fi

echo "ok: all $n entries succeeded"
