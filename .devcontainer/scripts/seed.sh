#!/usr/bin/env bash
# Populates the db with documents: makes sure a sector, a category and a user
# exist (the upload needs a categoryId and a creatorId), then uploads every
# given file through the running server's POST /api/v1/documents, which
# converts it to PDF and indexes it with akpedia-ml.
#
# Directories are walked recursively. A file inside a subdirectory of a given
# directory goes to the category named after that first-level subdirectory
# (created on demand); any other file goes to SEED_CATEGORY. With no paths,
# the sample documents listed in SAMPLES below (short public-domain FAA
# publications) are uploaded from .devcontainer/seed/<category>/ (git
# ignored), downloading only the ones not there yet. Safe to re-run: the base rows are looked up by
# their unique name/email instead of duplicated, and every document the seed
# user created before is deleted first (its file and embeddings go with it),
# so a re-run recreates the documents from scratch -- e.g. to retry ones
# whose indexing FAILED.
#
# Runs inside the devcontainer, which is attached to akpedia-db's network
# (see .devcontainer/entrypoint.sh), so the db is reached by container name.
# The server must be up (`akpedia run server`).
set -uo pipefail

DB_HOST="${DB_HOST:-akpedia-db}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-akpedia}"
DB_USER="${POSTGRES_USER:-akpedia}"
export PGPASSWORD="${POSTGRES_PASSWORD:-akpedia}"
SERVER_URL="${SERVER_URL:-http://localhost:8080}"
ML_URL="${ML_URL:-${EMBEDDING_BASE_URL:-http://localhost:8000}}"

SECTOR_NAME="${SEED_SECTOR:-TI}"
CATEGORY_NAME="${SEED_CATEGORY:-Manuais}"
USER_EMAIL="${SEED_USER_EMAIL:-ana@akpedia.test}"

FAA_HANDBOOKS=https://www.faa.gov/sites/faa.gov/files/regulations_policies/handbooks_manuals/aviation
FAA_ADDENDA=https://www.faa.gov/regulations_policies/handbooks_manuals/aviation
FEDERAL_REGISTER=https://www.govinfo.gov/content/pkg

# <category>|<document name>|<url>, uploaded when no paths are given. The
# name becomes the file name, which the server uses as the document name.
SAMPLES_DIR="$(cd "$(dirname "$0")/.." && pwd)/seed"
SAMPLES="\
Manuais|FAA-P-8740-39 Balloon Safety Tips|$FAA_HANDBOOKS/balloon_safety_tips.pdf
Manuais|FAA-P-8740-34 Powerlines and Thunderstorms|$FAA_HANDBOOKS/powerlines_and_thunderstorms.pdf
Manuais|FAA-P-8740-60 Tips on Mountain Flying|$FAA_HANDBOOKS/tips_on_mountain_flying.pdf
Manuais|FAA-H-8083-15B Addendum - Angle of Attack Indicators|$FAA_HANDBOOKS/ifh_addendum.pdf
Manuais|Weight and Balance Handbook Addendum (MOSAIC)|$FAA_ADDENDA/Weight_Balance_HB_Addendum_(MOSAIC).pdf
Manuais|Airplane Flying Handbook Addendum (MOSAIC)|$FAA_ADDENDA/AFH_Addendum_(MOSAIC).pdf
Manuais|Pilot's Handbook of Aeronautical Knowledge Addendum (MOSAIC)|$FAA_ADDENDA/PHAK_Addendum_(MOSAIC).pdf
Diretrizes de Aeronavegabilidade|AD 2026-19084 - Airbus SAS Airplanes|$FEDERAL_REGISTER/FR-2026-09-17/pdf/2026-19084.pdf
Diretrizes de Aeronavegabilidade|AD 2026-19083 - The Boeing Company Airplanes|$FEDERAL_REGISTER/FR-2026-09-17/pdf/2026-19083.pdf
Diretrizes de Aeronavegabilidade|AD 2026-19052 - Bell Textron Canada Helicopters|$FEDERAL_REGISTER/FR-2026-09-17/pdf/2026-19052.pdf
Diretrizes de Aeronavegabilidade|AD 2026-18848 - Pilatus Aircraft Airplanes|$FEDERAL_REGISTER/FR-2026-09-15/pdf/2026-18848.pdf
Diretrizes de Aeronavegabilidade|AD 2026-17584 - Lycoming Engines|$FEDERAL_REGISTER/FR-2026-08-28/pdf/2026-17584.pdf
Diretrizes de Aeronavegabilidade|AD 2026-18601 - Dassault Aviation Airplanes|$FEDERAL_REGISTER/FR-2026-09-11/pdf/2026-18601.pdf
Diretrizes de Aeronavegabilidade|AD 2026-16512 - BRP-Rotax Engines|$FEDERAL_REGISTER/FR-2026-08-13/pdf/2026-16512.pdf"

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      echo "usage: akpedia seed [file|dir...]" >&2
      echo "env: SERVER_URL, ML_URL, DB_HOST, DB_PORT, SEED_SECTOR, SEED_CATEGORY, SEED_USER_EMAIL" >&2
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

# The no-op DO UPDATE is what makes RETURNING hand back the id of an
# already existing row, not only of a freshly inserted one.
sector_id="$(sql -v name="$SECTOR_NAME" <<'SQL'
INSERT INTO sectors (name, description) VALUES (:'name', 'Setor de ' || :'name')
ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
RETURNING id;
SQL
)" || exit 1

# Prints the id of the category with the given name, creating it if needed.
declare -A category_ids
category_id() {
  if [ -z "${category_ids[$1]:-}" ]; then
    category_ids[$1]="$(sql -v name="$1" <<'SQL'
INSERT INTO categories (name, description) VALUES (:'name', :'name')
ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
RETURNING id;
SQL
)" || return 1
  fi
  echo "${category_ids[$1]}"
}

category_id "$CATEGORY_NAME" >/dev/null || exit 1

user_id="$(sql -v email="$USER_EMAIL" -v sector="$sector_id" <<'SQL'
INSERT INTO users (name, email, password_hash, sector_id)
VALUES (split_part(:'email', '@', 1), :'email', 'hash', :sector)
ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
RETURNING id;
SQL
)" || exit 1

echo "sector '$SECTOR_NAME': $sector_id" >&2
echo "category '$CATEGORY_NAME': ${category_ids[$CATEGORY_NAME]}" >&2
echo "user '$USER_EMAIL': $user_id" >&2

# Any HTTP answer will do (even a 404); only a refused connection means it's down.
if ! curl -sS -o /dev/null "$SERVER_URL" 2>/dev/null; then
  echo "cannot reach the server at $SERVER_URL (run 'akpedia run server' first)" >&2
  exit 1
fi

# Without akpedia-ml the upload still succeeds, but lands as FAILED.
if ! curl -fsS -o /dev/null "$ML_URL/health" 2>/dev/null; then
  echo "warning: akpedia-ml is not answering at $ML_URL: documents will be stored as FAILED (run 'akpedia run ml')" >&2
fi

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

deleted="$(sql -v creator="$user_id" <<'SQL'
WITH deleted AS (DELETE FROM documents WHERE creator_id = :creator RETURNING 1)
SELECT count(*) FROM deleted;
SQL
)" || exit 1
echo "deleted $deleted previously seeded document(s)" >&2

uploaded=0
failed=0
upload() { # <file> <category name>
  local file="$1" category_id response status
  # Not in a $(...) subshell: the category must stay cached for the next file.
  category_id "$2" >/dev/null || exit 1
  category_id="${category_ids[$2]}"
  response="$(mktemp)"
  status="$(curl -sS -o "$response" -w '%{http_code}' \
    -X POST "$SERVER_URL/api/v1/documents" \
    -F "file=@$file" \
    -F "categoryId=$category_id" \
    -F "creatorId=$user_id")"
  if [ "$status" = 201 ]; then
    uploaded=$((uploaded + 1))
    printf '\033[1;32m[%s]\033[0m %s (%s)\n' "$status" "$file" "$2"
  else
    failed=$((failed + 1))
    printf '\033[1;31m[%s]\033[0m %s: %s\n' "$status" "$file" "$(cat "$response")"
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

echo "uploaded: $uploaded, failed: $failed" >&2
[ "$failed" -eq 0 ]
