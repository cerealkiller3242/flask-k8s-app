#!/usr/bin/env bash
# Uso: ./scripts/balanceo.sh [peticiones] [url]
#      ./scripts/balanceo.sh [peticiones] in-cluster
# Lanza N peticiones al Service y cuenta cuántas atendió cada Pod.
# Usa "in-cluster" cuando el NodePort no es accesible desde el host
# (Docker Desktop con provisioner kind): las peticiones salen de un Pod
# temporal hacia http://flask-service:5000/, que sí balancea.
set -euo pipefail

N="${1:-10}"
URL="${2:-http://localhost:30080/}"

get_bodies() {
  if [ "$URL" = "in-cluster" ]; then
    kubectl run "balanceo-$RANDOM" --rm -i --restart=Never --image=curlimages/curl:8.11.1 -- \
      sh -c "for i in \$(seq 1 $N); do curl -s --max-time 3 http://flask-service:5000/; echo; done" \
      2>/dev/null | grep '^{'
  else
    for i in $(seq 1 "$N"); do
      curl -s --max-time 3 "$URL" || echo "SIN_RESPUESTA"
      echo
    done
  fi
}

echo "== $N peticiones a $URL =="
pods=""
i=0
while IFS= read -r body; do
  [ -z "$body" ] && continue
  i=$((i + 1))
  pod=$(echo "$body" | sed -n 's/.*"pod": *"\([^"]*\)".*/\1/p')
  echo "peticion $i -> ${pod:-respuesta inesperada: $body}"
  [ -n "$pod" ] && pods="$pods$pod"$'\n'
done < <(get_bodies)

echo
echo "== Peticiones por Pod =="
printf '%s' "$pods" | sort | uniq -c | sort -rn
