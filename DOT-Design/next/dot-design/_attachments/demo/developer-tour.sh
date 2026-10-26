#!/usr/bin/env bash
# Read-only developer extensions. No deploy/apply/tool-start or product copies.
set -euo pipefail
[[ "$#" == 1 ]] || { echo "Usage: $0 <--inspect|--guardrail>" >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
cd "$root"
case "${1:-}" in
  --inspect)
# tag::inspect[]
KEYCLOAK=DOT-Repository/DOTs/external/Keycloak-DOT
dotx validate "$KEYCLOAK" \
  --schema DOT-Repository/Schema/schema.json --profile reusable --offline

dotx inspect "$KEYCLOAK" --json |
  jq -e '{name, version,
          deployments: [.deployments[] |
            {id, platformEngine, type, supported}],
          anchor: (.anchors[] | select(.name == "admin-realm-read") |
            {name, role, contract})} |
         select(([.deployments[].platformEngine] | unique) ==
           ["DOCKER", "KUBERNETES"])'

sed -n '1,12p' \
  "$KEYCLOAK/contracts/keycloak-admin-rest.yaml"
# end::inspect[]
    ;;
  --guardrail)
    # Prove that the positive fixture resolves before testing a rejected wire.
    dotx compose validate DOT-Testing/composition/poc7-trust-scoring/scenario.yaml
    scratch="$(mktemp -d)"
    trap 'rm -rf -- "$scratch"' EXIT
    umask 077
    rejected=0
    dotx compose validate DOT-Testing/composition/poc7-trust-scoring/rejected-collector-scoring.yaml \
      > "$scratch/rejection.txt" 2>&1 || rejected=$?
    if [[ "$rejected" != 1 ]] || ! grep -Fq \
      'wire "scoring-api-to-collector": cannot compose a contract-backed anchor with a contractless anchor' \
      "$scratch/rejection.txt"; then
      echo "FAIL: expected the specific interface-compatibility rejection, got exit=$rejected." >&2
      echo 'Rerun dotx compose validate on the rejected fixture to inspect the diagnostic.' >&2
      exit 1
    fi
    printf '%s\n' \
      'EXPECTED REJECTION (exit=1): scoring-api-to-collector mixes Contract-backed and contractless Anchors.' \
      'The valid two-DOT graph has zero wires; no runtime was deployed by either validation command.'
    ;;
  *) echo "Usage: $0 <--inspect|--guardrail>" >&2; exit 2 ;;
esac
