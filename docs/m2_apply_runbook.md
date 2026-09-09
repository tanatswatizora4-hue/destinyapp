# M2 apply runbook (destiny-os only)

Target: **xchddfpfzrzhlbbmyhyn** — never Wanzwei.

**Flutter inventory API** already avoids live bymapara (PostgREST → Storage catalog → bundled asset).  
**Remaining M2 work** is remote schema/rows/media on destiny-os.

## Option A — New Cloud Agent run with secrets (preferred)

**Minimum:** one Personal Access Token (`SUPABASE_ACCESS_TOKEN`) with access to destiny-os.  
`apply_m2_remote.sh` bootstraps `service_role` + anon from the Management API when those are unset.

1. Create a PAT at https://supabase.com/dashboard/account/tokens (include API Keys read + SQL/database permissions needed for schema apply)
2. Add environment secret: `SUPABASE_ACCESS_TOKEN` (optionally also `SUPABASE_SERVICE_ROLE_KEY` / `DESTINY_SUPABASE_ANON_KEY`)
3. **Start a new agent** on `cursor/m2-destiny-backend-migration-194a` — mid-run secret adds may not inject
4. Agent runs:

```bash
bash scripts/m2_new_agent_bootstrap.sh
# = load creds → apply_m2_remote.sh → post-apply doc commit (if catalog 200)
# equivalent:
#   export SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co
#   export SUPABASE_ACCESS_TOKEN=...   # sufficient alone
#   bash scripts/apply_m2_remote.sh
```

If schema was already pasted in SQL Editor:

```bash
DESTINY_SKIP_SCHEMA=1 bash scripts/apply_m2_remote.sh
```

## Option B — GitHub Actions

Workflow: `.github/workflows/m2-destiny-supabase-apply.yml`

**Note:** GitHub only lists `workflow_dispatch` workflows on the **default branch**. PR #13 (`cursor/m2-gha-enable-194a` → `main`) registers the workflow; when running, select branch **`cursor/m2-destiny-backend-migration-194a`** (scripts + Git LFS media live there).

Repo Actions secret **required:** `SUPABASE_ACCESS_TOKEN`.  
Optional: `SUPABASE_SERVICE_ROLE_KEY`, `DESTINY_SUPABASE_ANON_KEY` (bootstrapped from the PAT when omitted).  
Then: Actions → **M2 Destiny Supabase apply** → Run workflow.

The workflow checks out with `lfs: true`, fails if the media tarball is still an LFS pointer, extracts ≥81 staged files, upserts inventory, uploads owned paths + `inventory/catalog.json`, then verifies when anon key is set.

## Option C — Dashboard SQL + Storage upload (no agent PAT)

Use this when you can sign into the Dashboard yourself but cannot (yet) give the agent a PAT.

1. **SQL Editor** (project `xchddfpfzrzhlbbmyhyn`): paste  
   `supabase/seed/m2_dashboard_schema_plus_seed.sql`  
   (schema + owned-media inventory rows). Schema-only alternative: `m2_dashboard_one_paste.sql`.
2. **Build / download the media pack** (81 images + `inventory/catalog.json`):

```bash
bash scripts/m2_build_dashboard_media_pack.sh
# → /tmp/m2-dashboard-media-pack.tar
# On the agent VNC helper: http://127.0.0.1:8765/m2-dashboard-media-pack.tar
```

3. **Storage → bucket `destiny-media`**: upload every member of the tar **preserving relative paths**  
   (`inventory/catalog.json`, `tours/...`, `stays/...`, `vehicles/...`, `awards/...`).
4. Confirm publicly:  
   `https://xchddfpfzrzhlbbmyhyn.supabase.co/storage/v1/object/public/destiny-media/inventory/catalog.json` → HTTP **200**
5. Still needed for full milestone verify (counts + sensitive deny): anon key or PAT so the agent can run `verify_m2_remote.py` / finalize. Drop PAT into the VNC form or add Cloud Agent secret + new agent.

Do **not** apply historical `inventory_seed.sql` for cutover (legacy `uploads/` paths).

## Option D — Sign into Supabase on agent desktop / CLI login

Open the agent VM desktop / VNC, sign into https://supabase.com/dashboard, open the CLI login URL waiting in tmux `sb-login`, then either:

- Paste the verification code into tmux `sb-login`, **or**
- Drop it for the code watcher (no chat paste):
  `printf '%s\n' 'YOUR_CODE' > /tmp/supabase-cli-code && chmod 600 /tmp/supabase-cli-code`  
  (`bash scripts/m2_watch_cli_code.sh` in tmux `m2-watch-cli-code` submits it automatically)

`apply_m2_remote.sh` auto-loads credentials when env vars are unset, in order:
1. Drop file **`/tmp/destiny-m2.env`** (`KEY=value` lines; `chmod 600`) — supports `SUPABASE_ACCESS_TOKEN` and/or `SUPABASE_SERVICE_ROLE_KEY` + `DESTINY_SUPABASE_ANON_KEY`
2. Raw PAT file **`/tmp/supabase-access-token`** (single line; `chmod 600`) — VNC-friendly paste of just the token
3. CLI file `~/.supabase/access-token` after a successful `supabase login`

Do not paste tokens into chat.

On long-running agent VMs, `bash scripts/m2_watch_and_apply.sh` (tmux `m2-watch-apply`) polls for the drop file / raw token / CLI token / env keys and runs `apply_m2_remote.sh` once credentials appear — then commits/pushes finalize docs via `m2_post_apply_commit.sh` when `inventory/catalog.json` is HTTP 200.

## Offline checks (no secrets)

```bash
python3 scripts/m2_preflight.py
python3 scripts/test_m2_migrate_unit.py
bash scripts/test_m2_cred_loader.sh
```

## Expected counts

| Entity | Count |
|--------|------:|
| Tours | 25 |
| Stays | 36 |
| Vehicles | 3 |
| Awards | 6 |
| Media staged locally | 81 / 84 (also in repo via Git LFS tarball) |
| Media missing (legacy 404) | 3 |

After remote verify, run Flutter with owned inventory media live:

```bash
--dart-define=DESTINY_INVENTORY_MEDIA_LIVE=true
--dart-define=DESTINY_SUPABASE_ANON_KEY=<publishable anon key>
```

(Until then, inventory `destiny-media/tours|stays|vehicles|awards` refs resolve through the legacy upload map so images keep working.)
