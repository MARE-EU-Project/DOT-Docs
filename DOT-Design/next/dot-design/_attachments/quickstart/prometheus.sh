#!/usr/bin/env bash
# Source these commands in Bash, or follow their tagged sections in Getting started.

# tag::select[]
DOT_REPOSITORY="${DOT_REPOSITORY:-$PWD}"
DOT_BUNDLE="$DOT_REPOSITORY/DOTs/external/Prometheus-DOT"
DOT_NAME="${DOT_NAME:-dot-quickstart}"
DOTX_HTTP_PORT="${DOTX_HTTP_PORT:-18909}"
DOT_PROJECT_FILTER="label=com.docker.compose.project=$DOT_NAME"
export DOTX_HTTP_PORT
# end::select[]

# tag::validate[]
dotx validate "$DOT_BUNDLE" --schema "$DOT_REPOSITORY/Schema/schema.json" \
  --profile reusable
dotx inspect "$DOT_BUNDLE" --json
dotx deploy "$DOT_BUNDLE" --deployment docker-compose --name "$DOT_NAME" --dry-run
# end::validate[]

# tag::deploy[]
dotx deploy "$DOT_BUNDLE" --deployment docker-compose --name "$DOT_NAME" \
  --env "DOTX_HTTP_PORT=$DOTX_HTTP_PORT"
# end::deploy[]

# tag::verify[]
ready=false
for ((attempt=0; attempt<60; attempt++)); do
  if curl --fail --silent --max-time 2 \
    "http://127.0.0.1:$DOTX_HTTP_PORT/-/ready"; then
    ready=true
    break
  fi
  sleep 1
done
test "$ready" = true
curl --fail --silent --show-error --max-time 5 \
  "http://127.0.0.1:$DOTX_HTTP_PORT/api/v1/status/buildinfo" |
  jq -e '.status == "success" and .data.version == "3.15.1"'
# end::verify[]

# tag::status[]
dotx ps
# end::status[]

# tag::cleanup[]
dotx destroy "$DOT_BUNDLE" --deployment docker-compose --name "$DOT_NAME" &&
remaining="$(docker ps -aq --filter "$DOT_PROJECT_FILTER")" &&
test -z "$remaining" &&
remaining="$(docker network ls -q --filter "$DOT_PROJECT_FILTER")" &&
test -z "$remaining" &&
remaining="$(docker volume ls -q --filter "$DOT_PROJECT_FILTER")" &&
test -z "$remaining"
# end::cleanup[]
