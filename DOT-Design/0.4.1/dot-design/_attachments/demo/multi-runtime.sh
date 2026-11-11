#!/usr/bin/env bash
# Run from the DOT-Design checkout root; Antora includes these same commands.
set -euo pipefail
case "${1:---dry-run}" in
  --dry-run)
# tag::dry-run[]
exec bash DOT-Testing/e2e/multi-runtime-demo/test.sh --dry-run
# end::dry-run[]
    ;;
  --live)
# tag::live[]
exec bash DOT-Testing/e2e/multi-runtime-demo/test.sh --live
# end::live[]
    ;;
  --present)
# tag::present[]
exec bash DOT-Testing/e2e/multi-runtime-demo/test.sh --present
# end::present[]
    ;;
  *) echo "Usage: $0 [--dry-run|--live|--present]" >&2; exit 2 ;;
esac
