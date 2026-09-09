# Agent instructions — Destiny M2 branch

Branch: `cursor/m2-destiny-backend-migration-194a`  
Target: Supabase project **`xchddfpfzrzhlbbmyhyn` only** (never Wanzwei).

## If `SUPABASE_ACCESS_TOKEN` (or service_role+anon) is present

Run immediately — do not wait for further human input:

```bash
bash scripts/m2_new_agent_bootstrap.sh
```

Then update PR #11 with live evidence. Mark the M2 milestone complete **only** when live verify proves: tours/stays/vehicles/awards = 25/36/3/6, ≥90% owned media paths, `inventory/catalog.json` HTTP 200, sensitive tables deny anon.

## If credentials are missing

```
STOP_REASON=CREDENTIAL_REQUIRED
```

Do **not** mark M2 complete. Keep waiting via:

- Env secret `SUPABASE_ACCESS_TOKEN` + new agent (preferred)
- VNC drop file `/tmp/destiny-m2.env` (`chmod 600`) — watcher `m2-watch-apply` auto-runs
- CLI login in tmux `sb-login`
- Dashboard paste `supabase/seed/m2_dashboard_schema_plus_seed.sql` (schema+rows; media still needs credentials)
- Merge PR #13 then Actions workflow with repo secret PAT

Never paste secrets into chat. Never target Wanzwei. Preserve `devBypassAuth` and Firebase Auth.
