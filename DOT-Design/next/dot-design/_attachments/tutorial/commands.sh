#!/usr/bin/env bash
# Tagged lesson excerpts, executed individually by the tutorial acceptance test.
# Follow the Antora lessons in order; this file is not an unattended installer.

# tag::workspace[]
# Start in the matching DOT-Repository checkout, in Bash.
set -o pipefail
DOT_REPOSITORY="$PWD" &&
PROMETHEUS_JSON="$(dotx repository resolve Prometheus@3.15.1 --repository "$DOT_REPOSITORY")" &&
DOTX_TUTORIAL_CLI="$(command -v dotx)" &&
DOTX_TUTORIAL_CLI_SHA256="$(sha256sum "$DOTX_TUTORIAL_CLI" | cut -d ' ' -f 1)" &&
LAB="$(mktemp -d "${DOTX_TUTORIAL_WORKSPACE:-$HOME}/dot-zero-to-hero.XXXXXXXX")" &&
DOT_BUNDLE="$(dirname -- "$PROMETHEUS_JSON")" &&
DOT_NAME="hero-$RANDOM-$RANDOM" &&
DOTX_HTTP_PORT="${DOTX_HTTP_PORT:-18909}" &&
TUTORIAL_PORT="${TUTORIAL_PORT:-19041}" &&
DASHBOARD_PORT="${DASHBOARD_PORT:-13000}" &&
export DOTX_HTTP_PORT XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}" &&
(umask 077; declare -p DOT_REPOSITORY LAB PROMETHEUS_JSON DOT_BUNDLE DOT_NAME \
  DOTX_HTTP_PORT TUTORIAL_PORT DASHBOARD_PORT XDG_CACHE_HOME \
  DOTX_TUTORIAL_CLI DOTX_TUTORIAL_CLI_SHA256 > "$LAB/session.bash") &&
printf 'Your private workspace: %s\nResume with: source %q\n' "$LAB" "$LAB/session.bash" &&
dotx version --verbose &&
git -C "$DOT_REPOSITORY" rev-parse HEAD
# end::workspace[]

# tag::resume[]
# Source your own saved session.bash first, using the command printed in Lesson 1.
set -o pipefail
if [[ -n "${DOTX_TUTORIAL_CLI:-}" && -n "${DOTX_TUTORIAL_CLI_SHA256:-}" &&
      -n "${LAB:-}" && -n "${DOT_REPOSITORY:-}" ]] &&
  test "$(sha256sum "$DOTX_TUTORIAL_CLI" | cut -d ' ' -f 1)" = "$DOTX_TUTORIAL_CLI_SHA256"; then
  DOTX_TUTORIAL_BIN_DIR="$(dirname -- "$DOTX_TUTORIAL_CLI")" &&
  export PATH="$DOTX_TUTORIAL_BIN_DIR:$PATH" &&
  dotx version --verbose &&
  printf 'Resumed existing workspace: %s\n' "$LAB"
else
  printf 'Saved session is missing/incomplete, or its CLI changed. Source your own session file and recover the recorded binary before managing this workspace.\n' >&2
  false
fi
# end::resume[]

# tag::first-check[]
(
set -euo pipefail
printf 'Checking Prometheus and the selected Docker Compose deployment; nothing starts yet...\n'
dotx validate "$DOT_BUNDLE" --repository "$DOT_REPOSITORY" --profile reusable
dotx inspect "$DOT_BUNDLE"
dotx deploy "$DOT_BUNDLE" --deployment docker-compose --name "$DOT_NAME" \
  --env "DOTX_HTTP_PORT=$DOTX_HTTP_PORT" --dry-run
printf 'Preview complete. Next: start this one instance and check its real API.\n'
)
# end::first-check[]

# tag::first-run[]
printf 'Starting Prometheus; Docker may download its pinned image on the first run...\n'
dotx deploy "$DOT_BUNDLE" --deployment docker-compose --name "$DOT_NAME" \
  --env "DOTX_HTTP_PORT=$DOTX_HTTP_PORT"
# end::first-run[]

# tag::first-stop[]
dotx destroy "$DOT_BUNDLE" --deployment docker-compose --name "$DOT_NAME" &&
remaining="$(docker ps -aq --filter "label=com.docker.compose.project=$DOT_NAME")" &&
test -z "$remaining" &&
remaining="$(docker network ls -q --filter "label=com.docker.compose.project=$DOT_NAME")" &&
test -z "$remaining" &&
remaining="$(docker volume ls -q --filter "label=com.docker.compose.project=$DOT_NAME")" &&
test -z "$remaining" &&
printf 'Cleanup verified: Prometheus containers, network and volumes are absent.\n'
# end::first-stop[]

# tag::author[]
(
set -euo pipefail
IMAGE="$(jq -r '.runtimes[].deployments[] |
  select(.id == "docker") | .manifest.image' "$PROMETHEUS_JSON")"
CONTRACT_URL="$(jq -r '.contracts[0].payload.url' "$PROMETHEUS_JSON")"
CONTRACT_SHA256="$(jq -r '.contracts[0].payload.sha256' "$PROMETHEUS_JSON")"

printf 'Creating a private Prometheus definition from the pinned official OpenAPI document...\n'
dotx new --from docker-image "$IMAGE" \
  --name Prometheus --version 3.15.1 --skill Metrics-Scraping \
  --service prometheus --port http:9090 \
  --contract-url "$CONTRACT_URL" --contract-sha256 "$CONTRACT_SHA256" \
  --contract-name HTTP --contract-standard OpenAPI --contract-format YAML \
  --operation 'build-information=#/paths/~1status~1buildinfo/get' \
  --operation 'promql-query-api=#/paths/~1query/get' --bind http \
  --output "$LAB/base/dot.json"

dotx validate "$LAB/base/dot.json" --repository "$DOT_REPOSITORY" --profile reusable
dotx inspect "$LAB/base/dot.json"
printf 'Draft verified: two provided Anchors. Open %s/base/dot.json to follow their Contract references.\n' "$LAB"
)
# end::author[]

# tag::complete[]
(
set -euo pipefail
set -o noclobber
mkdir "$LAB/prometheus"
jq --slurpfile product "$PROMETHEUS_JSON" '
  .anchors += [$product[0].anchors[] | select(.id == "scrape-target")]
  | .runtimes[0].deployments[0].services[0].ports[0].protocol = "HTTP"
  | .runtimes[0].deployments[0].services[0].config =
      ($product[0].runtimes[].deployments[] | select(.id == "docker")
       | .services[] | select(.id == "prometheus") | .config)
  | .runtimes[0].deployments +=
      [$product[0].runtimes[].deployments[] | select(.id == "docker-compose")]
' "$LAB/base/dot.json" > "$LAB/prometheus/dot.json"

dotx validate "$LAB/prometheus/dot.json" --repository "$DOT_REPOSITORY" --profile reusable
dotx inspect "$LAB/prometheus/dot.json"
printf 'Definition verified: three Anchors and two Docker deployment choices. Review the changes below.\n'
diff -u "$LAB/base/dot.json" "$LAB/prometheus/dot.json" || test "$?" -eq 1
)
# end::complete[]

# tag::config[]
(
set -euo pipefail
set -o noclobber
cat > "$LAB/prometheus.yml" <<'YAML'
global:
  scrape_interval: 5s
scrape_configs:
  - job_name: node-exporter
    static_configs:
      - targets: [node-exporter:9100]
        labels:
          tutorial: zero-to-hero
YAML
chmod 0644 "$LAB/prometheus.yml"
)
# end::config[]

# tag::draft[]
dotx compose new \
  --from "$DOT_REPOSITORY/Compositions/node-exporter-prometheus-monitoring/composition.yaml" \
  --repository "$DOT_REPOSITORY" --name zero-to-hero \
  --output "$LAB/composition.yaml" --yes
# end::draft[]

# The learner edits the draft as shown in the lesson before the next block.
# tag::review[]
(
set -euo pipefail
dotx compose validate "$LAB/composition.yaml" --repository "$DOT_REPOSITORY"
dotx compose lock "$LAB/composition.yaml" --repository "$DOT_REPOSITORY"
dotx compose inspect "$LAB/composition.yaml" --repository "$DOT_REPOSITORY" --locked
dotx compose topology "$LAB/composition.yaml" --repository "$DOT_REPOSITORY" --locked
dotx compose apply "$LAB/composition.yaml" --repository "$DOT_REPOSITORY" \
  --locked --dry-run --forward "prometheus-query=$TUTORIAL_PORT"
printf 'Graph verified: two DOTs, one Wire. No service has started.\n'
)
# end::review[]

# tag::run[]
printf 'Starting Node Exporter and your Prometheus; the next check waits for their labelled scrape...\n'
dotx compose apply "$LAB/composition.yaml" --repository "$DOT_REPOSITORY" \
  --locked --forward "prometheus-query=$TUTORIAL_PORT"
# end::run[]

# tag::query[]
(
set -euo pipefail
set -o pipefail
scraped=false
started=$SECONDS
next_notice=$SECONDS
printf 'Checking the labelled Node Exporter scrape through Prometheus...\n'
for ((attempt=0; attempt<90; attempt++)); do
  if curl --fail --silent --max-time 3 --get \
    --data-urlencode 'query=up{job="node-exporter",tutorial="zero-to-hero"}' \
    "http://127.0.0.1:$TUTORIAL_PORT/api/v1/query" |
    jq -e '.status == "success" and any(.data.result[]?; .value[1] == "1")' >/dev/null; then
    scraped=true
    break
  fi
  if ((SECONDS >= next_notice)); then
    printf 'Waiting for the scrape: attempt %s/90, %ss elapsed\n' "$((attempt + 1))" "$((SECONDS - started))"
    next_notice=$((SECONDS + 5))
  fi
  sleep 1
done
if ! $scraped; then
  printf 'Scrape check timed out. Inspect compose status, then run the Lesson 3 cleanup block before retrying.\n' >&2
  exit 1
fi
curl --fail --silent --show-error --max-time 5 \
  "http://127.0.0.1:$TUTORIAL_PORT/api/v1/status/buildinfo" |
  jq -e '.status == "success" and .data.version == "3.15.1"'
dotx compose status "$LAB/composition.yaml" --repository "$DOT_REPOSITORY"
printf 'Verified: your labelled Node Exporter scrape is up (value 1).\n'
printf 'Try the same query in Prometheus: http://127.0.0.1:%s/\n' "$TUTORIAL_PORT"
)
# end::query[]

# tag::stop[]
dotx compose destroy "$LAB/composition.yaml" --repository "$DOT_REPOSITORY"
# end::stop[]

# tag::dashboard-inputs[]
(
set -euo pipefail
set -o noclobber
GRAFANA_JSON="$(dotx repository resolve Grafana@13.3.0 --repository "$DOT_REPOSITORY")"
mkdir "$LAB/grafana"
jq '.runtimes[0].deployments[0].services[0].config.environment +=
  [{"name":"GF_SECURITY_ADMIN_PASSWORD","required":true,"sensitive":true}]' \
  "$GRAFANA_JSON" > "$LAB/grafana/dot.json"
dotx validate "$LAB/grafana/dot.json" --repository "$DOT_REPOSITORY" --profile reusable

cat > "$LAB/grafana-prometheus.yml" <<'YAML'
apiVersion: 1
datasources:
  - name: Prometheus
    uid: hero-prometheus
    type: prometheus
    access: proxy
    url: http://replaced-by-the-wire.invalid
    isDefault: true
YAML
cat > "$LAB/grafana-empty.yml" <<'YAML'
apiVersion: 1
datasources: []
YAML
chmod 0644 "$LAB/grafana-prometheus.yml" "$LAB/grafana-empty.yml"

dotx compose new --from "$LAB/composition.yaml" \
  --repository "$DOT_REPOSITORY" --name hero-dashboard \
  --output "$LAB/dashboard.yaml" --yes
)
# end::dashboard-inputs[]

# The learner appends the three YAML entries shown in the dashboard lesson.
# tag::dashboard-review[]
(
set -euo pipefail
dotx compose validate "$LAB/dashboard.yaml" --repository "$DOT_REPOSITORY"
dotx compose lock "$LAB/dashboard.yaml" --repository "$DOT_REPOSITORY"
dotx compose topology "$LAB/dashboard.yaml" --repository "$DOT_REPOSITORY" --locked
printf 'Extended graph verified: three DOTs, two Wires. Next: supply a lab password, then preview and apply.\n'
)
# end::dashboard-review[]

# tag::password[]
if read -r -s -p 'Choose a lab-only Grafana admin password: ' HERO_GRAFANA_PASSWORD &&
  test -n "$HERO_GRAFANA_PASSWORD"; then
  printf '\n'
  export HERO_GRAFANA_PASSWORD
else
  unset HERO_GRAFANA_PASSWORD
  printf '\nNo password set. Repeat this prompt before applying.\n' >&2
  false
fi
# end::password[]

# tag::dashboard-run[]
printf 'Previewing, then starting Node Exporter, Prometheus and Grafana; pinned images may need downloading...\n'
dotx compose apply "$LAB/dashboard.yaml" --repository "$DOT_REPOSITORY" \
  --locked --dry-run --forward "prometheus-query=$TUTORIAL_PORT" --forward "dashboard=$DASHBOARD_PORT" &&
dotx compose apply "$LAB/dashboard.yaml" --repository "$DOT_REPOSITORY" \
  --locked --forward "prometheus-query=$TUTORIAL_PORT" --forward "dashboard=$DASHBOARD_PORT"
# end::dashboard-run[]

# tag::dashboard-ready[]
(
set -euo pipefail
set -o pipefail
dashboard_ready=false
started=$SECONDS
next_notice=$SECONDS
printf 'Checking Grafana 13.3.0 health on port %s...\n' "$DASHBOARD_PORT"
for ((attempt=0; attempt<90; attempt++)); do
  if curl --fail --silent --max-time 3 "http://127.0.0.1:$DASHBOARD_PORT/api/health" |
    jq -e '.database == "ok" and .version == "13.3.0"' >/dev/null; then
    dashboard_ready=true
    break
  fi
  if ((SECONDS >= next_notice)); then
    printf 'Waiting for Grafana: attempt %s/90, %ss elapsed\n' "$((attempt + 1))" "$((SECONDS - started))"
    next_notice=$((SECONDS + 5))
  fi
  sleep 1
done
if ! $dashboard_ready; then
  printf 'Grafana health check timed out. Inspect compose status, then run the Lesson 4 cleanup block before retrying.\n' >&2
  exit 1
fi
printf 'Ready: Grafana 13.3.0 at http://127.0.0.1:%s/\n' "$DASHBOARD_PORT"
)
# end::dashboard-ready[]

# tag::dashboard-query[]
(
set -euo pipefail
set -o pipefail
# curl reads credentials from a private file, not command-line arguments.
credentials="$(mktemp "$LAB/grafana.curl.XXXXXXXX")"
trap 'rm -f -- "$credentials"' EXIT
(umask 077; jq -nr '"user = " + ("admin:" + env.HERO_GRAFANA_PASSWORD | tojson)' \
  > "$credentials")
dashboard_queried=false
started=$SECONDS
next_notice=$SECONDS
printf 'Querying the labelled scrape through Grafana...\n'
for ((attempt=0; attempt<90; attempt++)); do
  if curl --config "$credentials" --fail --silent --max-time 5 \
    --header 'Content-Type: application/json' \
    --data '{
      "from":"now-5m", "to":"now",
      "queries":[{
        "refId":"A",
        "expr":"up{job=\"node-exporter\",tutorial=\"zero-to-hero\"}",
        "instant":true,
        "datasource":{"type":"prometheus","uid":"hero-prometheus"}
      }]
    }' \
    "http://127.0.0.1:$DASHBOARD_PORT/api/ds/query" |
    jq -e '.results.A.status == 200 and
      any(.results.A.frames[]?.data.values[]?[]?; . == 1)' >/dev/null; then
    dashboard_queried=true
    break
  fi
  if ((SECONDS >= next_notice)); then
    printf 'Waiting for the Grafana query: attempt %s/90, %ss elapsed\n' "$((attempt + 1))" "$((SECONDS - started))"
    next_notice=$((SECONDS + 5))
  fi
  sleep 1
done
if ! $dashboard_queried; then
  printf 'Grafana query timed out. Check the password and datasource; run the Lesson 4 cleanup block before retrying.\n' >&2
  exit 1
fi
printf 'Verified: Grafana queried the labelled scrape (value 1).\n'
)
# end::dashboard-query[]

# tag::dashboard-stop[]
dotx compose destroy "$LAB/dashboard.yaml" --repository "$DOT_REPOSITORY" &&
unset HERO_GRAFANA_PASSWORD &&
{ if test -f "$LAB/grafana.curl"; then rm -- "$LAB/grafana.curl"; fi; } &&
printf 'Cleanup completed: keep the workspace files for reference.\n'
# end::dashboard-stop[]
