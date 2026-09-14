#!/usr/bin/env bash
# Runs the given modules (server, ml, client) in parallel for local dev.
# With no arguments, runs all three. Assumes the db is already up (started
# by .devcontainer/entrypoint.sh). Ctrl+C stops everything.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

trap 'kill -- -$$ 2>/dev/null' EXIT INT TERM

run() {
  local name="$1" color="$2" dir="$3"
  shift 3
  (
    cd "$dir"
    "$@" 2>&1 | while IFS= read -r line; do
      printf '\033[1;%sm[%s]\033[0m %s\n' "$color" "$name" "$line"
    done
  ) &
}

start_server() { run server 34 akpedia-server ./mvnw spring-boot:run; }
start_ml()     { run ml     35 akpedia-ml     uv run uvicorn app.main:app --reload --port "${APP_PORT:-8000}"; }
start_client() { run client 36 akpedia-client npm run dev; }

modules=("$@")
[ ${#modules[@]} -eq 0 ] && modules=(server ml client)

for m in "${modules[@]}"; do
  case "$m" in
    server | ml | client) ;;
    *)
      echo "unknown module: $m (expected: server, ml, client)" >&2
      exit 1
      ;;
  esac
done

for m in "${modules[@]}"; do
  case "$m" in
    server) start_server ;;
    ml) start_ml ;;
    client) start_client ;;
  esac
done

wait
