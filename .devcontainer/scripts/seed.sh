#!/usr/bin/env bash
# Populates the db with documents. Logs in to Keycloak as the development admin
# (KEYCLOAK_DEV_ADMIN_EMAIL / KEYCLOAK_DEV_ADMIN_PASSWORD, from the environment
# or akpedia-server/.env), the way the browser does (authorization code with
# PKCE), so the documents are attributed to that account. It accepts the
# current terms of use for that account if they are pending (no optional
# permission allowed), uploads every given file through the running server's
# POST /api/v1/documents, which converts it to PDF, and approves it, which
# indexes it with akpedia-ml.
#
# Directories are walked recursively. A file inside a subdirectory of a given
# directory goes to the category named after that first-level subdirectory;
# any other file goes to SEED_CATEGORY. Only the catalog's categories are used
# (Tecnico, Regulatorio, Juridico, Qualidade): the seed never creates one, and
# a file in a directory named after anything else is refused. With no paths,
# the sample documents listed in SAMPLES below (short public-domain FAA and
# Federal Register publications) are uploaded from .devcontainer/seed/<category>/
# (git ignored), downloading only the ones not there yet. Safe to re-run: a
# document the admin uploaded before under the same name is deleted first (its
# file and embeddings go with it), so a re-run recreates the documents from
# scratch -- e.g. to retry ones whose indexing FAILED.
#
# Runs inside the devcontainer, which is attached to akpedia-db's network
# (see .devcontainer/entrypoint.sh), so the db is reached by container name,
# and so is Keycloak. The server must be up (`akpedia run server`).
set -uo pipefail

DB_HOST="${DB_HOST:-akpedia-db}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-akpedia}"
DB_USER="${POSTGRES_USER:-akpedia}"
export PGPASSWORD="${POSTGRES_PASSWORD:-akpedia}"
SERVER_URL="${SERVER_URL:-http://localhost:8080}"
ML_URL="${ML_URL:-${EMBEDDING_BASE_URL:-http://localhost:8000}}"

CATEGORY_NAME="${SEED_CATEGORY:-Tecnico}"

# Keycloak's public URL (the tokens' issuer, which the server checks) and the
# container that answers it: requests to the public URL are sent there, so the
# login cookies and redirects keep the public host.
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost/auth}"
KEYCLOAK_CONTAINER="${KEYCLOAK_CONTAINER:-akpedia-keycloak:8080}"
CLIENT_ID="${KEYCLOAK_CLIENT_ID:-akpedia-client}"
CLIENT_URL="${AKPEDIA_CLIENT_URL:-http://localhost}"

# The development admin, from akpedia-server/.env unless set already.
ENV_FILE="$(cd "$(dirname "$0")/../.." && pwd)/akpedia-server/.env"
env_value() { # <name>: its value in ENV_FILE, if there
  [ -f "$ENV_FILE" ] && sed -n "s/^$1=//p" "$ENV_FILE" | tail -n 1 | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}
LOGIN_EMAIL="${SEED_LOGIN_EMAIL:-${KEYCLOAK_DEV_ADMIN_EMAIL:-$(env_value KEYCLOAK_DEV_ADMIN_EMAIL)}}"
LOGIN_EMAIL="${LOGIN_EMAIL:-admin@akpedia.local}"
LOGIN_PASSWORD="${SEED_LOGIN_PASSWORD:-${KEYCLOAK_DEV_ADMIN_PASSWORD:-$(env_value KEYCLOAK_DEV_ADMIN_PASSWORD)}}"

FAA_HANDBOOKS=https://www.faa.gov/sites/faa.gov/files/regulations_policies/handbooks_manuals/aviation
FAA_ADDENDA=https://www.faa.gov/regulations_policies/handbooks_manuals/aviation
FEDERAL_REGISTER=https://www.govinfo.gov/content/pkg

# <category>|<document name>|<url>, uploaded when no paths are given. The
# name becomes the file name, which the server uses as the document name.
SAMPLES_DIR="$(cd "$(dirname "$0")/.." && pwd)/seed"
SAMPLES="\
Tecnico|FAA-P-8740-39 Balloon Safety Tips|$FAA_HANDBOOKS/balloon_safety_tips.pdf
Tecnico|FAA-P-8740-34 Powerlines and Thunderstorms|$FAA_HANDBOOKS/powerlines_and_thunderstorms.pdf
Tecnico|FAA-H-8083-15B Addendum - Angle of Attack Indicators|$FAA_HANDBOOKS/ifh_addendum.pdf
Tecnico|Weight and Balance Handbook Addendum (MOSAIC)|$FAA_ADDENDA/Weight_Balance_HB_Addendum_(MOSAIC).pdf
Tecnico|Airplane Flying Handbook Addendum (MOSAIC)|$FAA_ADDENDA/AFH_Addendum_(MOSAIC).pdf
Tecnico|Pilot's Handbook of Aeronautical Knowledge Addendum (MOSAIC)|$FAA_ADDENDA/PHAK_Addendum_(MOSAIC).pdf
Regulatorio|AD 2026-19084 - Airbus SAS Airplanes|$FEDERAL_REGISTER/FR-2026-09-17/pdf/2026-19084.pdf
Regulatorio|AD 2026-19083 - The Boeing Company Airplanes|$FEDERAL_REGISTER/FR-2026-09-17/pdf/2026-19083.pdf
Regulatorio|AD 2026-19052 - Bell Textron Canada Helicopters|$FEDERAL_REGISTER/FR-2026-09-17/pdf/2026-19052.pdf
Regulatorio|AD 2026-18848 - Pilatus Aircraft Airplanes|$FEDERAL_REGISTER/FR-2026-09-15/pdf/2026-18848.pdf
Regulatorio|AD 2026-17584 - Lycoming Engines|$FEDERAL_REGISTER/FR-2026-08-28/pdf/2026-17584.pdf
Regulatorio|AD 2026-18601 - Dassault Aviation Airplanes|$FEDERAL_REGISTER/FR-2026-09-11/pdf/2026-18601.pdf
Regulatorio|AD 2026-16512 - BRP-Rotax Engines|$FEDERAL_REGISTER/FR-2026-08-13/pdf/2026-16512.pdf"

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      echo "usage: akpedia seed [file|dir...]" >&2
      echo "env: SERVER_URL, ML_URL, DB_HOST, DB_PORT, SEED_CATEGORY, KEYCLOAK_URL, KEYCLOAK_CONTAINER," >&2
      echo "     SEED_LOGIN_EMAIL, SEED_LOGIN_PASSWORD (default: the dev admin in akpedia-server/.env)" >&2
      exit 0
      ;;
  esac
  if [ ! -e "$arg" ]; then
    echo "no such file or directory: $arg" >&2
    exit 1
  fi
done

sql() {
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -v ON_ERROR_STOP=1 -qtAX "$@"
}

if ! sql -c 'SELECT 1' >/dev/null; then
  echo "cannot reach the db at $DB_HOST:$DB_PORT (is akpedia-db up?)" >&2
  exit 1
fi

# The schema is created by the server's Flyway migrations on startup.
if [ "$(sql -c "SELECT to_regclass('public.sectors') IS NOT NULL")" != t ]; then
  echo "the db has no schema yet: start the server once ('akpedia run server') to migrate it" >&2
  exit 1
fi

# Any HTTP answer will do (even a 404); only a refused connection means it's down.
if ! curl -sS -o /dev/null "$SERVER_URL" 2>/dev/null; then
  echo "cannot reach the server at $SERVER_URL (run 'akpedia run server' first)" >&2
  exit 1
fi

# Without akpedia-ml the documents still upload and get approved, but their indexing FAILS.
if ! curl -fsS -o /dev/null "$ML_URL/health" 2>/dev/null; then
  echo "warning: akpedia-ml is not answering at $ML_URL: indexing will fail (run 'akpedia run ml')" >&2
fi

if [ -z "$LOGIN_PASSWORD" ]; then
  echo "no password for $LOGIN_EMAIL: set KEYCLOAK_DEV_ADMIN_PASSWORD in akpedia-server/.env (or SEED_LOGIN_PASSWORD)" >&2
  exit 1
fi

# Prints a field of the JSON on stdin, e.g. `json id` or `json current.version`; empty if absent.
json() {
  python3 -c '
import json, sys
value = json.load(sys.stdin)
for key in sys.argv[1].split("."):
    value = value.get(key) if isinstance(value, dict) else None
print("" if value is None else value)' "$1"
}

# --- Login: authorization code with PKCE, as akpedia-client does in the browser ---
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
cookies="$workdir/cookies"
keycloak_host="${KEYCLOAK_URL#*://}"
keycloak_host="${keycloak_host%%/*}"
case "$keycloak_host" in *:*) ;; *) keycloak_host="$keycloak_host:80" ;; esac
kc_curl() { curl -sS -b "$cookies" -c "$cookies" --connect-to "$keycloak_host:$KEYCLOAK_CONTAINER" "$@"; }

verifier="$(openssl rand -base64 48 | tr -d '\n=+/' | cut -c1-64)"
challenge="$(printf '%s' "$verifier" | openssl dgst -sha256 -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')"
redirect_uri="$CLIENT_URL/"
auth_url="$KEYCLOAK_URL/realms/akpedia/protocol/openid-connect/auth?client_id=$CLIENT_ID&response_type=code&scope=openid&code_challenge_method=S256&code_challenge=$challenge&redirect_uri=$(printf '%s' "$redirect_uri" | python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))')"

login_form="$(kc_curl "$auth_url")" || { echo "cannot reach Keycloak at $KEYCLOAK_CONTAINER" >&2; exit 1; }
action="$(printf '%s' "$login_form" | grep -o 'action="[^"]*login-actions/authenticate[^"]*"' | head -n 1 | sed -e 's/^action="//' -e 's/"$//' -e 's/&amp;/\&/g')"
if [ -z "$action" ]; then
  echo "Keycloak did not show its login form (is the akpedia realm there?)" >&2
  exit 1
fi
location="$(kc_curl -o /dev/null -w '%{redirect_url}' \
  --data-urlencode "username=$LOGIN_EMAIL" --data-urlencode "password=$LOGIN_PASSWORD" \
  --data-urlencode "credentialId=" "$action")"
code="$(printf '%s' "$location" | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p')"
if [ -z "$code" ]; then
  echo "could not log in to Keycloak as $LOGIN_EMAIL (wrong password, or an action pending on the account)" >&2
  exit 1
fi
token="$(kc_curl "$KEYCLOAK_URL/realms/akpedia/protocol/openid-connect/token" \
  --data-urlencode grant_type=authorization_code --data-urlencode "code=$code" \
  --data-urlencode "client_id=$CLIENT_ID" --data-urlencode "redirect_uri=$redirect_uri" \
  --data-urlencode "code_verifier=$verifier" | json access_token)"
if [ -z "$token" ]; then
  echo "Keycloak did not hand out a token for $LOGIN_EMAIL" >&2
  exit 1
fi

api() { curl -sS -H "Authorization: Bearer $token" "$@"; }

# Creates the user's row on the server, as the first request after a login does.
me="$(api "$SERVER_URL/api/v1/me")"
user_id="$(printf '%s' "$me" | json id)"
if [ -z "$user_id" ]; then
  echo "the server did not take the login: $me" >&2
  exit 1
fi
echo "logged in as $LOGIN_EMAIL (user $user_id)" >&2

# Nothing else is open until the current terms are accepted.
terms="$(api "$SERVER_URL/api/v1/terms")"
current_terms="$(printf '%s' "$terms" | json current.version)"
if [ -n "$current_terms" ] && [ "$current_terms" != "$(printf '%s' "$terms" | json accepted.version)" ]; then
  api -o /dev/null -X POST -H 'Content-Type: application/json' \
    -d "{\"version\": \"$current_terms\"}" "$SERVER_URL/api/v1/terms/accept" || exit 1
  echo "accepted the terms of use $current_terms for $LOGIN_EMAIL (no optional permission allowed)" >&2
fi

# Prints the id of the catalog category with the given name (any case); fails for anything else:
# the seed files documents under the catalog, it never adds to it.
declare -A category_ids
category_id() {
  if [ -z "${category_ids[$1]:-}" ]; then
    category_ids[$1]="$(sql -v name="$1" <<<"SELECT id FROM categories WHERE lower(name) = lower(:'name');")" || return 1
    if [ -z "${category_ids[$1]}" ]; then
      echo "no category named '$1'; the catalog has: $(sql <<<"SELECT string_agg(name, ', ' ORDER BY id) FROM categories;")" >&2
      return 1
    fi
  fi
  echo "${category_ids[$1]}"
}

category_id "$CATEGORY_NAME" >/dev/null || exit 1
echo "category '$CATEGORY_NAME': ${category_ids[$CATEGORY_NAME]}" >&2

if [ $# -eq 0 ]; then
  while IFS='|' read -r category name url; do
    file="$SAMPLES_DIR/$category/$name.pdf"
    [ -f "$file" ] && continue
    echo "downloading $category/$name.pdf" >&2
    mkdir -p "$SAMPLES_DIR/$category"
    # Through a .part file, so an interrupted download is retried next time.
    if curl -fsSL -A 'Mozilla/5.0' -o "$file.part" "$url"; then
      mv "$file.part" "$file"
    else
      echo "warning: could not download $url, skipping it" >&2
      rm -f "$file.part"
    fi
  done <<<"$SAMPLES"
  set -- "$SAMPLES_DIR"
fi

uploaded=0
failed=0
replaced=0
upload() { # <file> <category name>
  local file="$1" category_id response status name id approve
  # Not in a $(...) subshell: the category must stay cached for the next file.
  category_id "$2" >/dev/null || exit 1
  category_id="${category_ids[$2]}"
  name="$(basename "$file")"
  name="${name%.*}"
  # A re-run replaces what it uploaded before (its file and embeddings go with it).
  replaced=$((replaced + $(sql -v creator="$user_id" -v name="$name" <<'SQL'
WITH deleted AS (DELETE FROM documents WHERE creator_id = :creator AND name = :'name' RETURNING 1)
SELECT count(*) FROM deleted;
SQL
)))
  response="$(mktemp)"
  status="$(api -o "$response" -w '%{http_code}' \
    -X POST "$SERVER_URL/api/v1/documents" \
    -F "file=@$file" \
    -F "categoryId=$category_id" \
    --form-string "name=$name")"
  if [ "$status" != 201 ]; then
    failed=$((failed + 1))
    printf '\033[1;31m[%s]\033[0m %s: %s\n' "$status" "$file" "$(cat "$response")"
    rm -f "$response"
    return
  fi
  # Uploads wait for an approver; approving is what sends the document to be indexed.
  id="$(json id <"$response")"
  approve="$(api -o "$response" -w '%{http_code}' -X POST "$SERVER_URL/api/v1/documents/$id/approve")"
  if [ "$approve" = 200 ] || [ "$approve" = 204 ]; then
    uploaded=$((uploaded + 1))
    printf '\033[1;32m[%s]\033[0m %s (%s)\n' "$status" "$file" "$2"
  else
    failed=$((failed + 1))
    printf '\033[1;31m[%s]\033[0m %s: uploaded as document %s, but approving it failed: %s\n' \
      "$approve" "$file" "$id" "$(cat "$response")"
  fi
  rm -f "$response"
}

for arg in "$@"; do
  if [ ! -d "$arg" ]; then
    upload "$arg" "$CATEGORY_NAME"
    continue
  fi
  root="${arg%/}"
  while IFS= read -r -d '' file; do
    rel="${file#"$root"/}"
    if [[ "$rel" == */* ]]; then
      upload "$file" "${rel%%/*}"
    else
      upload "$file" "$CATEGORY_NAME"
    fi
  done < <(find "$root" -type f -print0)
done

echo "uploaded and approved: $uploaded, failed: $failed (replaced $replaced previously seeded)" >&2
[ "$failed" -eq 0 ]
