#!/usr/bin/env bash
# Executed by the focused authoring acceptance runner and included in Antora.

# tag::inputs[]
# Run from DOT-Design; set DOT_REPOSITORY=$PWD from a standalone catalogue.
DOT_REPOSITORY="${DOT_REPOSITORY:-$PWD/DOT-Repository}"
AUTHORING_DIR="$(mktemp -d -t dotx-authoring.XXXXXXXX)"
jq '.contracts[0]' "$DOT_REPOSITORY/DOTs/external/Prometheus-DOT/dot.json" \
  >"$AUTHORING_DIR/contract.json"
# end::inputs[]

# tag::create[]
dotx new --from docker-image prom/prometheus:v3.15.1 \
  --name Prometheus --version 3.15.1 --skill Metrics-Scraping \
  --service prometheus --port http:9090 \
  --contract "$AUTHORING_DIR/contract.json" \
  --operation 'build-information=#/paths/~1status~1buildinfo/get' --bind http \
  --output "$AUTHORING_DIR/bundle/dot.json"
# end::create[]

# tag::check[]
dotx validate "$AUTHORING_DIR/bundle" \
  --schema "$DOT_REPOSITORY/Schema/schema.json" --profile reusable
dotx inspect "$AUTHORING_DIR/bundle"
dotx deploy "$AUTHORING_DIR/bundle" --deployment docker-image --dry-run
# end::check[]

# tag::url-create[]
# Alternative: supply the official raw URL without hand-writing contract.json.
# This exercise creates no second catalogue entry.
AUTHORING_SPEC_BASE=https://raw.githubusercontent.com/prometheus/prometheus/v3.15.1
dotx new --from docker-image prom/prometheus:v3.15.1 \
  --name Prometheus --version 3.15.1 --skill Metrics-Scraping \
  --service prometheus --port http:9090 \
  --contract-url "$AUTHORING_SPEC_BASE/web/api/v1/testdata/openapi_3.1_golden.yaml" \
  --contract-name HTTP --contract-version 0.0.1-undefined --contract-format YAML \
  --operation 'build-information=#/paths/~1status~1buildinfo/get' --bind http \
  --output "$AUTHORING_DIR/url-bundle/dot.json"
dotx validate "$AUTHORING_DIR/url-bundle" \
  --schema "$DOT_REPOSITORY/Schema/schema.json" --profile reusable
jq '.contracts[0]' "$AUTHORING_DIR/url-bundle/dot.json"
# end::url-create[]

# tag::cleanup[]
# Only the files created by this exercise; unexpected extra files are retained.
rm -- "$AUTHORING_DIR/bundle/dot.json" "$AUTHORING_DIR/contract.json"
if [[ -d "$AUTHORING_DIR/url-bundle" ]]; then
  rm -- "$AUTHORING_DIR/url-bundle/dot.json"
  rmdir -- "$AUTHORING_DIR/url-bundle"
fi
rmdir -- "$AUTHORING_DIR/bundle" "$AUTHORING_DIR"
# end::cleanup[]
