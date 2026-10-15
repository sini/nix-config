# Matrix: moving Synapse's login to MAS

Synapse's kanidm login is legacy SSO (`m.login.sso`), which Element X refuses.
The fix is the Matrix Authentication Service (`communication/matrix/mas.nix`),
with kanidm as its upstream provider and Synapse delegating all auth to it.

Existing accounts, devices and access tokens (including `@genie`'s) are imported
by `mas-cli syn2mas`. The tool wants Synapse stopped and MAS not running while
it imports. ArgoCD self-heals manual scaling, so each step is its own commit,
pushed and synced in order. Wait for each step to finish before pushing the
next.

## 1. MAS beside Synapse: check and dry run

Commit: `matrix: add MAS beside Synapse, with a syn2mas check and dry run`.

Push it, then deploy kanidm's new redirect URL: `colmena apply --on uplink`.

Synapse keeps serving. The `mas-syn2mas-check` Job runs `syn2mas check`, then a
full import that it rolls back:

```bash
kubectl -n matrix logs job/mas-syn2mas-check -c check
kubectl -n matrix logs job/mas-syn2mas-check
```

Errors block the migration. Expect one warning: Synapse's JWT login (the
`synapse-admins` job's) has no MAS counterpart, and step 3 removes it.

## 2. Stop Synapse and import

Commit: `matrix: stop Synapse and import its accounts into MAS`.

Synapse scales to 0 and the `mas-syn2mas-migrate` Job imports. Matrix is down
from here until step 3 syncs.

```bash
kubectl -n matrix logs -f job/mas-syn2mas-migrate
```

If it fails: fix the cause and re-run by deleting the Job (ArgoCD recreates it).
syn2mas never writes to Synapse's database, so reverting the commit restores
service. If it complains the MAS database is not empty, drop and recreate the
`mas` database first.

## 3. Synapse delegates to MAS

Commit: `matrix: delegate Synapse's auth to MAS`.

Synapse returns with `matrix_authentication_service` enabled, MAS starts, and
`matrix-auth.json64.dev` plus the `/login`, `/logout` and `/refresh` routes go
live. Then deploy kanidm again (`colmena apply --on uplink`) to drop Synapse's
old callback URL.

Check:

```bash
curl -s https://matrix.json64.dev/_matrix/client/v1/auth_metadata | jq .issuer
curl -s https://matrix.json64.dev/_matrix/client/v3/login | jq '.flows[].type'
```

The first prints `https://matrix-auth.json64.dev/`, and the second lists
`m.login.sso`, served by MAS. Element X now logs in with "json64.dev".

## After the migration

- Server admins are MAS's `policy.data.admin_users`, computed from kanidm's
  `admins` group. Ketesa (`matrix-admin.json64.dev`) logs in through MAS and
  asks for the admin scope.
- A bot token: `agenix generate` runs `mas-cli manage issue-compatibility-token`
  in the MAS pod. The bot account must exist first:
  `kubectl -n matrix exec deploy/matrix-authentication-service -- mas-cli manage register-user --yes <name>`.
- The imported `@synapse-admins` account is unused. Deactivate it from Ketesa.
