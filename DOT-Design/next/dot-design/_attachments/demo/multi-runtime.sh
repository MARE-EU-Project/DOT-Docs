#!/usr/bin/env bash
# Run from the DOT-Design checkout root; Antora includes these same commands.
set -euo pipefail
case "${1:---dry-run}" in
  --dry-run)
# tag::dry-run[]
bash DOT-Testing/e2e/multi-runtime-demo/test.sh --dry-run
# end::dry-run[]
    ;;
  --live)
# tag::live[]
bash DOT-Testing/e2e/multi-runtime-demo/test.sh --live
# end::live[]
    ;;
  *) echo "Usage: $0 [--dry-run|--live]" >&2; exit 2 ;;
esac
