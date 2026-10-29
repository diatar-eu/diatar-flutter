#!/bin/sh
set -eu

export LD_LIBRARY_PATH="/app/bin/lib:/app/lib"
# Check plugins too: several are loaded dynamically, not linked by the runner.
# shellcheck disable=SC2016
find /app -path /app/lib/debug -prune -o \
  -type f \( -name '*.so' -o -name '*.so.*' -o -executable \) -print0 |
  xargs -0 -r sh -c '
    for library do
      output=$(ldd "$library" 2>&1) || {
        case "$output" in
          *"not a dynamic executable"*|*"statically linked"*) continue ;;
          *) printf "%s\n%s\n" "$library" "$output" >&2; exit 1 ;;
        esac
      }
      case "$output" in
        *"not found"*) printf "%s\n%s\n" "$library" "$output" >&2; exit 1 ;;
      esac
    done
  ' sh
