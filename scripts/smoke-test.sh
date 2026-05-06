#!/usr/bin/env sh
set -eu

. ./scripts/load-env.sh

attempts="${SMOKE_ATTEMPTS:-24}"
sleep_seconds="${SMOKE_SLEEP_SECONDS:-5}"

request_with_retry() {
  url="$1"
  current_attempt=1

  while [ "$current_attempt" -le "$attempts" ]; do
    if curl -fsS "$url" >/dev/null; then
      printf "ok: %s\n" "$url"
      return 0
    fi

    printf "waiting: %s (%s/%s)\n" "$url" "$current_attempt" "$attempts"
    current_attempt=$((current_attempt + 1))
    sleep "$sleep_seconds"
  done

  printf "failed: %s\n" "$url" >&2
  return 1
}

request_with_retry "http://kube-starter.localhost:8080/api/health"
request_with_retry "http://kube-starter.localhost:8080/api/stats"
request_with_retry "http://grafana.localhost:8080/login"
request_with_retry "http://prometheus.localhost:8080/-/ready"
