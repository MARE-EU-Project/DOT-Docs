#!/usr/bin/env bash
# Tagged lesson excerpts, executed individually by the tutorial acceptance test.
# Follow the Antora lessons in order; this file is not an unattended installer.

# tag::workspace[]
# Start in the matching DOT-Repository checkout, in Bash.
DOT_REPOSITORY="$PWD"
LAB="$(mktemp -d "${DOTX_TUTORIAL_WORKSPACE:-$HOME}/dot-zero-to-hero.XXXXXXXX")"
PROMETHEUS_JSON="$(dotx repository resolve Prometheus@3.15.1 --repository "$DOT_REPOSITORY")"
DOT_BUNDLE="$(dirname -- "$PROMETHEUS_JSON")"
DOT_NAME="hero-$RANDOM-$RANDOM"
DOTX_HTTP_PORT="${DOTX_HTTP_PORT:-18909}"
TUTORIAL_PORT="${TUTORIAL_PORT:-19041}"
DASHBOARD_PORT="${DASHBOARD_PORT:-13000}"
export DOTX_HTTP_PORT
(umask 077; declare -p DOT_REPOSITORY LAB PROMETHEUS_JSON DOT_BUNDLE DOT_NAME \
  DOTX_HTTP_PORT TUTORIAL_PORT DASHBOARD_PORT > "$LAB/session.bash")
printf 'Your private workspace: %s\n' "$LAB"
dotx version --verbose
git -C "$DOT_REPOSITORY" rev-parse HEAD
# end::workspace[]

# tag::first-check[]
dotx validate "$DOT_BUNDLE" --repository "$DOT_REPOSITORY" --profile reusable
dotx inspect "$DOT_BUNDLE"
dotx deploy "$DOT_BUNDLE" --deployment docker-compose --name "$DOT_NAME" \
  --env "DOTX_HTTP_PORT=$DOTX_HTTP_PORT" --dry-run
# end::first-check[]

# tag::first-run[]
dotx deploy "$DOT_BUNDLE" --deployment docker-compose --name "$DOT_NAME" \
  --env "DOTX_HTTP_PORT=$DOTX_HTTP_PORT"
# end::first-run[]

# tag::first-stop[]
dotx destroy "$DOT_BUNDLE" --deployment docker-compose --name "$DOT_NAME" &&
test -z "$(docker ps -aq --filter "label=com.docker.compose.project=$DOT_NAME")" &&
test -z "$(docker network ls -q --filter "label=com.docker.compose.project=$DOT_NAME")" &&
test -z "$(docker volume ls -q --filter "label=com.docker.compose.project=$DOT_NAME")"
# end::first-stop[]

# tag::author[]
IMAGE="$(jq -r '.runtimes[].deployments[] |
  select(.id == "docker") | .manifest.image' "$PROMETHEUS_JSON")"
CONTRACT_URL="$(jq -r '.contracts[0].payload.url' "$PROMETHEUS_JSON")"
CONTRACT_SHA256="$(jq -r '.contracts[0].payload.sha256' "$PROMETHEUS_JSON")"

dotx new --from docker-image "$IMAGE" \
  --name Prometheus --version 3.15.1 --skill Metrics-Scraping \
  --service prometheus --port http:9090 \
  --contract-url "$CONTRACT_URL" --contract-sha256 "$CONTRACT_SHA256" \
  --contract-name HTTP --contract-standard OpenAPI --contract-format YAML \
  --operation 'build-information=#/paths/~1status~1buildinfo/get' \
  --operation 'promql-query-api=#/paths/~1query/get' --bind http \
  --output "$LAB/base/dot.json"

dotx validate "$LAB/base/dot.json" --repository "$DOT_REPOSITORY" --profile reusable
dotx inspect "$LAB/base/dot.json" --verbose
# end::author[]

# tag::complete[]
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
dotx inspect "$LAB/prometheus/dot.json" --verbose
diff -u "$LAB/base/dot.json" "$LAB/prometheus/dot.json" || test "$?" -eq 1
# end::complete[]

# tag::config[]
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
# end::config[]

# tag::draft[]
dotx compose new \
  --from "$DOT_REPOSITORY/Compositions/node-exporter-prometheus-monitoring/composition.yaml" \
  --repository "$DOT_REPOSITORY" --name zero-to-hero \
  --output "$LAB/composition.yaml" --yes
# end::draft[]

# The learner edits the draft as shown in the lesson before the next block.
# tag::review[]
dotx compose validate "$LAB/composition.yaml" --repository "$DOT_REPOSITORY"
dotx compose lock "$LAB/composition.yaml" --repository "$DOT_REPOSITORY"
dotx compose inspect "$LAB/composition.yaml" --repository "$DOT_REPOSITORY" --locked
dotx compose topology "$LAB/composition.yaml" --repository "$DOT_REPOSITORY" --locked
dotx compose apply "$LAB/composition.yaml" --repository "$DOT_REPOSITORY" \
  --locked --dry-run --forward "prometheus-query=$TUTORIAL_PORT"
# end::review[]

# tag::run[]
dotx compose apply "$LAB/composition.yaml" --repository "$DOT_REPOSITORY" \
  --locked --forward "prometheus-query=$TUTORIAL_PORT"
# end::run[]

# tag::query[]
set -o pipefail
scraped=false
for ((attempt=0; attempt<90; attempt++)); do
  if curl --fail --silent --max-time 3 --get \
    --data-urlencode 'query=up{job="node-exporter",tutorial="zero-to-hero"}' \
    "http://127.0.0.1:$TUTORIAL_PORT/api/v1/query" |
    jq -e '.status == "success" and any(.data.result[]?; .value[1] == "1")' >/dev/null; then
    scraped=true
    break
  fi
  sleep 1
done
test "$scraped" = true &&
curl --fail --silent --show-error --max-time 5 \
  "http://127.0.0.1:$TUTORIAL_PORT/api/v1/status/buildinfo" |
  jq -e '.status == "success" and .data.version == "3.15.1"' &&
dotx compose status "$LAB/composition.yaml" --repository "$DOT_REPOSITORY"
# end::query[]

# tag::stop[]
dotx compose destroy "$LAB/composition.yaml" --repository "$DOT_REPOSITORY"
# end::stop[]

# tag::dashboard-inputs[]
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
# end::dashboard-inputs[]

# The learner appends the three YAML entries shown in the dashboard lesson.
# tag::dashboard-review[]
dotx compose validate "$LAB/dashboard.yaml" --repository "$DOT_REPOSITORY"
dotx compose lock "$LAB/dashboard.yaml" --repository "$DOT_REPOSITORY"
dotx compose topology "$LAB/dashboard.yaml" --repository "$DOT_REPOSITORY" --locked
# end::dashboard-review[]

# tag::password[]
read -r -s -p 'Choose a lab-only Grafana admin password: ' HERO_GRAFANA_PASSWORD
printf '\n'
test -n "$HERO_GRAFANA_PASSWORD" &&
export HERO_GRAFANA_PASSWORD
# end::password[]

# tag::dashboard-run[]
dotx compose apply "$LAB/dashboard.yaml" --repository "$DOT_REPOSITORY" \
  --locked --dry-run --forward "prometheus-query=$TUTORIAL_PORT" --forward "dashboard=$DASHBOARD_PORT"
dotx compose apply "$LAB/dashboard.yaml" --repository "$DOT_REPOSITORY" \
  --locked --forward "prometheus-query=$TUTORIAL_PORT" --forward "dashboard=$DASHBOARD_PORT"
# end::dashboard-run[]

# tag::dashboard-ready[]
set -o pipefail
dashboard_ready=false
for ((attempt=0; attempt<90; attempt++)); do
  if curl --fail --silent --max-time 3 "http://127.0.0.1:$DASHBOARD_PORT/api/health" |
    jq -e '.database == "ok" and .version == "13.3.0"' >/dev/null; then
    dashboard_ready=true
    break
  fi
  sleep 1
done
test "$dashboard_ready" = true
# end::dashboard-ready[]

# tag::dashboard-query[]
set -o pipefail
# curl reads credentials from a private file, not command-line arguments.
(umask 077; jq -nr '"user = " + ("admin:" + env.HERO_GRAFANA_PASSWORD | tojson)' \
  > "$LAB/grafana.curl")
dashboard_queried=false
for ((attempt=0; attempt<90; attempt++)); do
  if curl --config "$LAB/grafana.curl" --fail --silent --max-time 5 \
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
  sleep 1
done
test "$dashboard_queried" = true &&
printf 'Verified: Grafana queried the labelled scrape (value 1).\n' &&
rm -- "$LAB/grafana.curl"
# end::dashboard-query[]

# tag::dashboard-stop[]
dotx compose destroy "$LAB/dashboard.yaml" --repository "$DOT_REPOSITORY"
unset HERO_GRAFANA_PASSWORD
if test -f "$LAB/grafana.curl"; then rm -- "$LAB/grafana.curl"; fi
# end::dashboard-stop[]
