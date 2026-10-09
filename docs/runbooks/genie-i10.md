# Runbook: the `genie-*` users and the Opus expert on bitstream (I10)

The aspect `services.ai.genie-expert`
(`modules/den/aspects/services/ai/genie-expert.nix`) puts the Opus tier of
`@genie` on **bitstream**.

**Users: one per sender tier, `genie-public` (uid 944) and `genie-trusted` (uid
943).**

- Both are system users, each with its own 0700 home (`/var/lib/genie-<tier>`)
  and its own Claude state.
- They are different uids, so neither tier can read the other's files or reach
  its processes.
- Neither has extra groups (not `wheel`, not `users`), sshd refuses both, and
  neither has an ssh agent, gh, kube or agenix identity.

**Two expert instances, `genie-expert@public` and `genie-expert@trusted`.** Each
sees its repos at `/var/lib/genie/repos` and its memory at
`/var/lib/genie/memory`. Both are bound inside the instance's own mount
namespace, never on the host.

- **`@trusted`:**
  - its repos are the owner's checkouts (`settings.checkouts`), mounted
    read-only inside the trusted home at `/var/lib/genie-trusted/repos/<name>`;
  - its memory is `~sini/.claude/memory`.
- **`@public`:**
  - its repos are clean clones of the **public** repos only
    (`settings.publicRepos`), at their published `main`. They live in
    `/var/lib/genie/public-repos`, fetched from GitHub by the
    `genie-public-repos` service, with no working-tree extras;
  - its memory is `support-memory/` of the genie-agent clone, where a merged PR
    is the admission;
  - den-ag-design and gen-progress-report-v1 are private (`gh repo view`) and
    never reach it.
- **Hardening:** `ProtectSystem=strict`, `ReadWritePaths` limited to the
  instance's own home, `HOME` = that home, `PrivateTmp`, `ProtectHome`,
  `NoNewPrivileges`.

**Token:** the agenix secret `genie-claude-token` is **root**-owned, 0400, so no
genie-\* shell can read it. systemd reads it as root for each instance's
`LoadCredential`, and the instance exports it as `CLAUDE_CODE_OAUTH_TOKEN`.

**Sandbox settings:** the bubblewrap sandbox is on, and commands cannot opt out
of it.

- Sandboxed commands may not read the token, `/run/agenix.d`, `/run/credentials`
  or `/proc/*/environ`, and see no `CLAUDE_CODE_OAUTH_TOKEN` variable.
- Claude's own Read tool is denied the same paths.

The secret and both instances stay **off** until
`.secrets/hosts/bitstream/genie-claude-token.age` exists in git, and every
bitstream eval prints `genie-expert: genie-claude-token.age is absent` until
then. So there are two deploys: first the users, mounts and clones, then the
token.

Run everything from the nix-config devshell on your workstation unless a step
says "on bitstream".

## 0. Pre-checks

The branch must be on `main`. The isolation properties are a flake check, which
evaluates bitstream:

```bash
nix build --no-link -L .#checks.x86_64-linux.genie-expert
```

Expected: `genie-expert: 22 properties + settingsDenyRead hold`, exit 0. A
failure prints `genie-expert: failed: <property names>` and exits 1. Among the
properties:

- `publicReposOnlyPublic`, `publicMemoryFromGenieAgent` and
  `publicNoOwnerClaude` cover what the public tier can see;
- `tiersSeparateUids` checks that each tier runs as its own uid, and
  `homesPrivate` that each home is asserted 0700 and owned by its tier, on the
  live path and on its `/persist` source;
- `privateTmp` and `protectSystemStrict` cover the hardening;
- `secretRootOwned` checks the secret's owner.

Then check that bitstream evaluates as a whole:

```bash
nix eval --raw .#nixosConfigurations.bitstream.config.system.build.toplevel.drvPath
```

Expected: a `/nix/store/...-nixos-system-bitstream-....drv` path and the
`genie-expert: ... absent` warning.

Re-check the visibility of every public repo. A repo made private since must
leave `publicRepos` first:

```bash
for r in $(nix eval --raw .#nixosConfigurations.bitstream.config.systemd.services.genie-public-repos.serviceConfig.ExecStart \
  | cut -d' ' -f2- | tr -d "'"); do
  printf '%s %s\n' "$r" "$(gh repo view "sini/$r" --json visibility -q .visibility)"
done | grep -v ' PUBLIC$'
```

Expected: no output.

On bitstream, check the trusted sources. A bind mount keeps the source's
permissions, so the trusted tier can read only what is world-readable:

```bash
stat -c '%A %U %n' ~/.claude/memory ~/.claude/memory/*.md | head
ls -d ~/Documents/repos/sini/{den-ag-design,xmsg,matrix-xmsg,gen*}
```

Expected:

- memory is `drwxr-xr-x` and its files are `-rw-r--r--`;
- every checkout named in `checkouts` exists. A missing one fails its own mount
  unit and does not block boot.

Also check that genie-agent's `main` on GitHub has a `support-memory/`
directory:

```bash
gh api repos/sini/genie-agent/contents/support-memory -q '.[].name' | head
```

Expected: no error. Without it, `genie-expert@public` fails to start: it fails
closed.

## 1. Deploy the users, the mounts and the public clones

```bash
colmena apply --on bitstream
```

Expected: the deploy succeeds and prints the `genie-expert: ... absent` warning.

Verify on bitstream:

```bash
id genie-public; id genie-trusted
stat -c '%A %U %n' /var/lib/genie-public /var/lib/genie-trusted
findmnt -R /var/lib/genie-trusted/repos -o TARGET,SOURCE,OPTIONS | head
findmnt -R /var/lib/genie -o TARGET,SOURCE
sudo systemctl start genie-public-repos; systemctl status genie-public-repos
ls /var/lib/genie/public-repos
git -C /var/lib/genie/public-repos/gen status --short --ignored
sudo -u genie-public ls /var/lib/genie-trusted
systemctl list-timers genie-public-repos
systemctl list-units 'genie-expert@*'
```

Expected:

- `id`: `groups=944(genie-public)` and `groups=943(genie-trusted)`, each and
  nothing else;
- `stat`: both homes `drwx------`, each owned by its own user. If either reads
  `drwxr-xr-x root`, run `sudo systemd-tmpfiles --create` and re-check; a
  persisting `root` owner is a defect. Stop, and do not create the token;
- `sudo stat -c '%A %U %n' /persist/var/lib/genie-public /persist/var/lib/genie-trusted`:
  the same, `drwx------` and the tier's own user;
- the first `findmnt`: one row per checkout, every one with `ro`;
- the second `findmnt`: only the persistence mount of
  `/var/lib/genie/public-repos`, and nothing at `/var/lib/genie/memory` or
  `/var/lib/genie/repos` (the views exist only inside the instances);
- `genie-public-repos`: `status=0/SUCCESS`;
- `ls`: exactly the `publicRepos` names, with no den-ag-design and no
  gen-progress-report-v1;
- `git status --short --ignored`: no output (a clean clone);
- `ls /var/lib/genie-trusted` as genie-public: `Permission denied`;
- the timer is listed;
- no expert units.

**Rollback:** `ssh bitstream sudo nixos-rebuild switch --rollback`. To also drop
the state:
`sudo rm -rf /persist/var/lib/genie-public /persist/var/lib/genie-trusted /persist/var/lib/genie`.

## 2. Create the token secret

The token is genie's own: a long-lived token from `claude setup-token`, used by
no one else and revocable on its own. Mint it in a throwaway config directory so
it touches no existing Claude state:

```bash
d=$(mktemp -d); CLAUDE_CONFIG_DIR=$d claude setup-token; rm -rf "$d"
```

It opens (or prints) a browser URL. Finish the login, and it prints the token.
Encrypt it with the YubiKey plugged in. Paste the token into the editor rather
than echoing it, so it stays out of shell history:

```bash
agenix edit .secrets/hosts/bitstream/genie-claude-token.age
git add .secrets/hosts/bitstream/genie-claude-token.age
agenix rekey -a
git add .secrets/hosts/bitstream
git commit -m "bitstream: genie-claude-token"
```

Pre-check: the warning is gone, the check still holds, and the secret evaluates:

```bash
nix build --no-link -L .#checks.x86_64-linux.genie-expert
nix eval --json .#nixosConfigurations.bitstream.config.age.secrets.genie-claude-token \
  --apply 's: { inherit (s) owner mode path; }'
```

Expected: `22 properties + settingsDenyRead hold`, and
`{"mode":"0400","owner":"root","path":"/run/agenix/genie-claude-token"}`.

**Rollback:** `git revert` the commit, then revoke the token in the Claude
account's settings, where it lists its long-lived tokens.

## 3. Deploy the expert

```bash
colmena apply --on bitstream
```

Verify on bitstream:

```bash
ls -l /run/agenix/genie-claude-token
systemctl status genie-expert@public genie-expert@trusted
for t in public trusted; do
  pid=$(systemctl show -p MainPID --value genie-expert@$t)
  ps -o user= -p "$pid"
  sudo nsenter -t "$pid" -m findmnt -o TARGET,SOURCE,OPTIONS /var/lib/genie/memory
  sudo nsenter -t "$pid" -m findmnt -o TARGET,SOURCE,OPTIONS /var/lib/genie/repos
done
```

Expected:

- the secret: `-r-------- 1 root root`;
- both units `active (running)`;
- in the loop, `public` runs as `genie-public`:
  - memory SOURCE `.../var/lib/genie/public-repos/genie-agent/support-memory`;
  - repos SOURCE `.../var/lib/genie/public-repos`;
- `trusted` runs as `genie-trusted`:
  - memory SOURCE `.../home/sini/.claude/memory`;
  - repos SOURCE `/var/lib/genie-trusted/repos`;
- every row has `ro`.

On the first start, attach to each tier and answer Claude's onboarding and
folder-trust prompts once. No login is needed, because the token is in the
environment. Detach with `C-b d`.

```bash
sudo -u genie-public tmux -S /run/genie-expert-public/tmux.sock attach
sudo -u genie-trusted tmux -S /run/genie-expert-trusted/tmux.sock attach
```

**Rollback:**

- Immediate: `sudo systemctl stop genie-expert@public genie-expert@trusted`.
- Durable: `git rm` the `.age`, commit and `colmena apply --on bitstream`. The
  instances and the secret are gated off again, while the users, mounts and
  clones stay.
- Full: `ssh bitstream sudo nixos-rebuild switch --rollback`.

## 4. Live verification

On the host, first confirm that neither tier can read the token outside any
sandbox:

```bash
sudo -u genie-public cat /run/agenix/genie-claude-token
sudo -u genie-trusted cat /run/agenix/genie-claude-token
```

Expected: `Permission denied`, twice.

Then attach to each tier and ask Claude to run each command with its Bash tool,
which is the sandboxed path.

In **both** tiers:

| command                                                         | expected                      |
| --------------------------------------------------------------- | ----------------------------- |
| `cat /run/agenix/genie-claude-token`                            | fails (denied / no such file) |
| `cat /run/credentials/genie-expert@<tier>.service/claude-token` | fails                         |
| `cat /proc/self/environ`                                        | fails                         |
| `cat /proc/1/environ`                                           | fails                         |
| `echo "${CLAUDE_CODE_OAUTH_TOKEN:-unset}"`                      | `unset`                       |
| `echo "$HOME"`                                                  | `/var/lib/genie-<tier>`       |
| `git -C /var/lib/genie/repos/gen log -1 --oneline`              | prints the commit             |
| `touch /var/lib/genie/repos/gen/x`                              | `Read-only file system`       |
| `touch /etc/x /var/lib/x`                                       | `Read-only file system`       |
| `touch ~/x && rm ~/x`                                           | succeeds (home is writable)   |
| `ls /tmp`                                                       | only the instance's own files |
| `ls /home/sini`                                                 | fails (`ProtectHome`)         |

Then ask it to **Read**, with the Read tool rather than Bash,
`/run/agenix/genie-claude-token` and `/proc/self/environ`. Expected: both
refused by permission rules.

In **trusted**:

| command                                   | expected                   |
| ----------------------------------------- | -------------------------- |
| `head -3 /var/lib/genie/memory/MEMORY.md` | prints the index           |
| `ls /var/lib/genie/repos/den-ag-design`   | lists the owner's checkout |
| `touch /var/lib/genie/memory/x`           | `Read-only file system`    |
| `ls /var/lib/genie-public`                | `Permission denied`        |

In **public**:

| command                                               | expected                                 |
| ----------------------------------------------------- | ---------------------------------------- |
| `ls -A /var/lib/genie/memory`                         | genie-agent's `support-memory/` contents |
| `ls /var/lib/genie/memory/MEMORY.md`                  | no such file (it is not sini's memory)   |
| `ls /var/lib/genie/repos/den-ag-design`               | no such file (private repo)              |
| `ls /var/lib/genie/repos/gen-progress-report-v1`      | no such file (private repo)              |
| `git -C /var/lib/genie/repos/gen status --ignored -s` | no output (clean clone)                  |
| `ls /var/lib/genie-trusted`                           | `Permission denied`                      |
| `touch /var/lib/genie/memory/x`                       | `Read-only file system`                  |

From the public tier's Read tool,
`/proc/<trusted MainPID>/root/var/lib/genie/memory/MEMORY.md` must be refused
with `Permission denied`, because the process belongs to another uid. Get the
PID on the host with `systemctl show -p MainPID --value genie-expert@trusted`.

If any row disagrees, stop both instances (step 3's rollback) and report the row
verbatim.

## Logs

```bash
journalctl -u genie-expert@public -u genie-expert@trusted -u genie-public-repos -f
```

- `Failed to set up credentials` / `LoadCredential`: the secret is missing or
  not rekeyed (`ls -l /run/agenix/genie-claude-token`).
- `Failed to set up mount namespacing`, naming `.../genie-agent/support-memory`
  (public): genie-agent's `main` has no `support-memory/` yet, or the clone
  failed.
- The same error naming `/home/sini/.claude/memory` (trusted): the source is
  absent on bitstream.
- `genie-public-repos: <repo> failed`: that clone or fetch failed. The others
  still ran, and the unit is marked failed.
- An instance starts and then exits: the tmux server died. Attach fails, and
  `journalctl` shows Claude's own error.
