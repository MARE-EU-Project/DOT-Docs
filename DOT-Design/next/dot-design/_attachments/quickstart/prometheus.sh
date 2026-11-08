#!/usr/bin/env bash
# Follow the tagged Getting started blocks in Bash, one at a time.
# This shared excerpt file is not an unattended installer.

# tag::select[]
DOT_REPOSITORY="${DOT_REPOSITORY:-$PWD}" &&
DOT_DEFINITION="$(dotx repository resolve Prometheus@3.15.1 --repository "$DOT_REPOSITORY")" &&
DOT_BUNDLE="$(dirname -- "$DOT_DEFINITION")" &&
DOT_NAME="${DOT_NAME:-dot-quickstart-$RANDOM-$RANDOM}" &&
DOTX_HTTP_PORT="${DOTX_HTTP_PORT:-18909}" &&
DOT_PROJECT_FILTER="label=com.docker.compose.project=$DOT_NAME" &&
export DOTX_HTTP_PORT &&
printf 'Selected: Prometheus 3.15.1; instance %s; host port %s. Keep this shell for cleanup.\n' "$DOT_NAME" "$DOTX_HTTP_PORT"
# end::select[]

# tag::validate[]
(
set -euo pipefail
printf 'Checking the definition and previewing Docker Compose; nothing starts yet...\n'
dotx validate "$DOT_BUNDLE" --schema "$DOT_REPOSITORY/Schema/schema.json" \
  --profile reusable
dotx inspect "$DOT_BUNDLE"
dotx deploy "$DOT_BUNDLE" --deployment docker-compose --name "$DOT_NAME" --dry-run
)
# end::validate[]

# tag::deploy[]
dotx deploy "$DOT_BUNDLE" --deployment docker-compose --name "$DOT_NAME" \
  --env "DOTX_HTTP_PORT=$DOTX_HTTP_PORT"
# end::deploy[]

# tag::verify[]
(
set -euo pipefail
ready=false
started=$SECONDS
next_notice=$SECONDS
printf 'Checking Prometheus readiness on port %s...\n' "$DOTX_HTTP_PORT"
for ((attempt=0; attempt<60; attempt++)); do
  if curl --fail --silent --max-time 2 \
    "http://127.0.0.1:$DOTX_HTTP_PORT/-/ready"; then
    ready=true
    break
  fi
  if ((SECONDS >= next_notice)); then
    printf 'Waiting for Prometheus: attempt %s/60, %ss elapsed\n' "$((attempt + 1))" "$((SECONDS - started))"
    next_notice=$((SECONDS + 5))
  fi
  sleep 1
done
if ! $ready; then
  printf 'Prometheus readiness timed out. Run the cleanup block before retrying.\n' >&2
  exit 1
fi
curl --fail --silent --show-error --max-time 5 \
  "http://127.0.0.1:$DOTX_HTTP_PORT/api/v1/status/buildinfo" |
  jq -e '.status == "success" and .data.version == "3.15.1"'
printf 'Verified: Prometheus 3.15.1 answered its official API. Open http://127.0.0.1:%s/\n' "$DOTX_HTTP_PORT"
)
# end::verify[]

# tag::status[]
dotx ps
# end::status[]

# tag::diagnose[]
(
set -euo pipefail
containers="$(docker ps -aq --filter "label=com.docker.compose.project=$DOT_NAME")"
if test -z "$containers"; then
  printf 'No containers found for this instance: %s\n' "$DOT_NAME" >&2
  exit 1
fi
while IFS= read -r container; do
  printf '\nLogs for this instance container: %s\n' "$container"
  docker logs --tail=100 "$container"
done <<< "$containers"
)
# end::diagnose[]

# tag::cleanup[]
dotx destroy "$DOT_BUNDLE" --deployment docker-compose --name "$DOT_NAME" &&
remaining="$(docker ps -aq --filter "$DOT_PROJECT_FILTER")" &&
test -z "$remaining" &&
remaining="$(docker network ls -q --filter "$DOT_PROJECT_FILTER")" &&
test -z "$remaining" &&
remaining="$(docker volume ls -q --filter "$DOT_PROJECT_FILTER")" &&
test -z "$remaining"
# end::cleanup[]
