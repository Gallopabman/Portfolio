#!/usr/bin/env bash
# Renderiza el chart para cada (ambiente, celda, servicio) exactamente como lo haría el
# ApplicationSet (mismo orden de values y mismos parámetros) y valida los manifiestos contra los
# esquemas de Kubernetes y de los CRDs. Lo corre la CI en cada PR; también sirve en local.
#
#   ./scripts/render-all.sh            # valida todo
#   OUT=rendered ./scripts/render-all.sh   # además deja los manifiestos en ./rendered para revisar el diff
set -euo pipefail
cd "$(dirname "$0")/.."

CHART=charts/service
OUT="${OUT:-}"
fail=0
count=0

for svc_file in environments/*/*/services/*.yaml; do
  env="$(echo "$svc_file" | cut -d/ -f2)"
  cell="$(echo "$svc_file" | cut -d/ -f3)"
  svc="$(basename "$svc_file" .yaml)"
  args=(--set "name=$svc" --set "cell.name=$cell" --set "cell.env=$env")
  for f in "environments/$env/env-values.yaml" "environments/$env/$cell/cell-values.yaml" "$svc_file"; do
    [ -f "$f" ] && args+=(-f "$f")
  done

  if ! manifests="$(helm template "$svc" "$CHART" "${args[@]}")"; then
    echo "FAIL render  $env/$cell/$svc"; fail=1; continue
  fi
  if [ -n "$OUT" ]; then
    mkdir -p "$OUT/$env/$cell"; printf '%s\n' "$manifests" > "$OUT/$env/$cell/$svc.yaml"
  fi
  if ! printf '%s\n' "$manifests" | kubeconform -strict -summary=false \
      -schema-location default \
      -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
      -; then
    echo "FAIL schema  $env/$cell/$svc"; fail=1; continue
  fi
  echo "ok           $env/$cell/$svc"
  count=$((count + 1))
done

# Reglas propias, más allá del esquema.
if grep -rnE '^\s*tag:\s*"?latest"?\s*$' environments/; then
  echo "FAIL policy  hay servicios con tag latest"; fail=1
fi

echo "$count combinaciones válidas"
exit $fail
