#!/usr/bin/env bash
# After a successful apply_m2_remote.sh, commit finalize-doc updates and push.
# Never prints secrets. Safe to run repeatedly (no-op if clean tree).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Guard: refuse if remote catalog still missing (weak evidence of failed apply)
CATALOG_URL="${SUPABASE_URL:-https://xchddfpfzrzhlbbmyhyn.supabase.co}"
CATALOG_URL="${CATALOG_URL%/}/storage/v1/object/public/destiny-media/inventory/catalog.json"
code="$(curl -s -o /dev/null -w '%{http_code}' "$CATALOG_URL" || true)"
if [[ "$code" != "200" ]]; then
  echo "ERROR: inventory/catalog.json HTTP $code (expected 200) — refusing commit" >&2
  exit 1
fi

branch="$(git branch --show-current)"
if [[ "$branch" != cursor/m2-destiny-backend-migration-194a ]]; then
  echo "WARN: on branch $branch (expected cursor/m2-destiny-backend-migration-194a)" >&2
fi

# Finalize docs typically touch these; stage any dirty docs under docs/ + related seeds
mapfile -t changed < <(git status --porcelain -- docs/ assets/data/supabase/seed/ | awk '{print $2}')
if [[ ${#changed[@]} -eq 0 ]]; then
  echo "No finalize doc changes to commit"
  echo "docs_clean" >/tmp/m2-finalize-commit-ready
  exit 0
fi

git add -- docs/ assets/data/supabase/seed/ || true
if git diff --cached --quiet; then
  echo "Nothing staged after add"
  echo "docs_clean" >/tmp/m2-finalize-commit-ready
  exit 0
fi

git commit -m "$(cat <<'EOF'
Finalize M2 docs from live Destiny verify evidence

Record remote apply evidence (counts, media, catalog) after successful
schema/inventory/media migration to xchddfpfzrzhlbbmyhyn.
EOF
)"

git push -u origin "$branch"
echo "pushed" >/tmp/m2-finalize-commit-ready
echo "Committed and pushed finalize docs on $branch"
