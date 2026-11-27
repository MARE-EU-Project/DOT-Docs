#!/usr/bin/env bash
# Read-only developer extensions. No deploy/apply/tool-start or product copies.
set -euo pipefail
[[ "$#" == 1 ]] || { echo "Usage: $0 <--inspect|--guardrail>" >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
cd "$root"
case "${1:-}" in
  --inspect)
# tag::inspect[]
KEYCLOAK=DOT-Repository/DOTs/external/Keycloak/26.8.1
dotx validate "$KEYCLOAK" \
  --schema DOT-Repository/Schema/schema.json --profile reusable --offline

dotx inspect "$KEYCLOAK" --json |
  jq -e '{name, version,
          deployments: [.deployments[] |
            {id, platformEngine, type, supported}],
          connector: (.connectors[] | select(.name == "admin-realm-read") |
            {name, role, contract})} |
         select(([.deployments[].platformEngine] | unique) ==
           ["DOCKER", "KUBERNETES"])'

jq -e '.contracts[] | select(.name == "Admin") |
       {id, name, version, standard, format, payload}' "$KEYCLOAK/dot.json"
# end::inspect[]
    ;;
  --guardrail)
    # Prove that the positive fixture resolves before testing a rejected edge.
    dotx compose validate DOT-Testing/e2e/poc7-trust-scoring/scenario.yaml
    scratch="$(mktemp -d)"
    trap 'rm -rf -- "$scratch"' EXIT
    umask 077
    rejected=0
    dotx compose validate DOT-Testing/composition/poc7-trust-scoring/rejected-collector-scoring.yaml \
      > "$scratch/rejection.txt" 2>&1 || rejected=$?
    if [[ "$rejected" != 1 ]] || ! grep -Fq \
      'channel "scoring-api-to-collector" on edge "trust-scoring-engine-to-netflow-collector": cannot compose a contract-backed connector with a contractless connector' \
      "$scratch/rejection.txt"; then
      echo "FAIL: expected the specific interface-compatibility rejection, got exit=$rejected." >&2
      echo 'Rerun dotx compose validate on the rejected fixture to inspect the diagnostic.' >&2
      exit 1
    fi
    printf '%s\n' \
      'EXPECTED REJECTION (exit=1): scoring-api-to-collector mixes Contract-backed and contractless Connectors.' \
      'The source-adapted three-DOT graph validates. These checks do not deploy workloads.'
    ;;
  *) echo "Usage: $0 <--inspect|--guardrail>" >&2; exit 2 ;;
esac
