#!/usr/bin/env bash
# Runs the given modules (server, ml, client) in parallel for local dev.
# With no arguments, runs all three; `ml` is the API plus the indexing worker.
# Assumes the db and Redis are already up (started by .devcontainer/entrypoint.sh).
# Ctrl+C stops everything.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

trap 'kill -- -$$ 2>/dev/null' EXIT INT TERM

# Shared secret of the server's /internal routes, which the ml worker calls back. Both get it
# from here, so it only has to be set to override this development value.
export INTERNAL_API_TOKEN="${INTERNAL_API_TOKEN:-akpedia-dev-internal-token}"

# The server checks the login tokens against Keycloak's keys. It reaches Keycloak by container
# name, while the tokens keep naming the public URL (http://localhost/auth, through nginx) as
# their issuer.
export KEYCLOAK_JWK_SET_URI="${KEYCLOAK_JWK_SET_URI:-http://akpedia-keycloak:8080/auth/realms/akpedia/protocol/openid-connect/certs}"
# The admin's users screen calls Keycloak's Admin API the same way, by container name.
export KEYCLOAK_ADMIN_BASE_URL="${KEYCLOAK_ADMIN_BASE_URL:-http://akpedia-keycloak:8080/auth}"

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

# Waits for the server to answer before starting the worker: started first, it would take a
# document from the queue, fail to download it, and fail to report that too.
wait_for_server() {
  local url="${SERVER_BASE_URL:-http://localhost:8080}" said=
  until curl -s -o /dev/null "$url"; do
    [ -z "$said" ] && echo "waiting for the server at $url" && said=1
    sleep 2
  done
}

# Pulls the local LLM into the Ollama volume once; later runs find it and skip this.
ensure_llm_model() {
  local model="${LLM_MODEL:-qwen2.5:3b-instruct}"
  docker exec akpedia-ollama ollama list | grep -q "$model" && return 0
  echo "pulling LLM model $model (~2 GB, only once)"
  docker exec akpedia-ollama ollama pull "$model"
}

start_server() { run server 34 akpedia-server ./mvnw spring-boot:run; }
start_ml()     { run ml     35 akpedia-ml     uv run uvicorn app.main:app --reload --host 0.0.0.0 --port "${APP_PORT:-8000}"; }
# Indexes approved documents; part of `ml`. Redis is reached by container name, as the server
# does it, and the consumer name is fixed so a restart resumes the worker's own pending messages.
export -f wait_for_server
start_worker() {
  run worker 33 akpedia-ml env \
    REDIS_URL="${REDIS_URL:-redis://${REDIS_HOST:-localhost}:${REDIS_PORT:-6379}/0}" \
    WORKER_CONSUMER="${WORKER_CONSUMER:-akpedia-dev-worker}" \
    bash -c 'wait_for_server && exec uv run python -m app.worker'
}
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
    ml)
      ensure_llm_model || echo "could not pull the LLM model; is akpedia-ollama running?" >&2
      start_ml
      start_worker
      ;;
    client) start_client ;;
  esac
done

wait
