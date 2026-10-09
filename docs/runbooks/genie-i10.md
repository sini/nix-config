# Runbook: the `genie` user and the Opus expert on bitstream (I10)

The aspect `services.ai.genie-expert`
(`modules/den/aspects/services/ai/genie-expert.nix`) puts the Opus tier of
`@genie` on **bitstream**:

- **User `genie`:** a system user with home `/var/lib/genie`, no extra groups
  (not `wheel`, not `users`), and refused by sshd (`DenyUsers genie`). It has no
  ssh agent, gh, kube or agenix identity.
- **Checkouts:** read-only bind mounts at `/var/lib/genie/repos/<name>`, one per
  name in `settings.services.ai.genie-expert.checkouts`, shared by both tiers.
- **Two expert instances, one per sender tier:**
  - `genie-expert@public` sees the curated `/var/lib/genie/support-memory` at
    `/var/lib/genie/memory`.
  - `genie-expert@trusted` sees `~sini/.claude/memory` at the same path.
  - The memory views are bound **inside each instance's mount namespace**, never
    on the host, so no session can see both.
  - Each tier keeps its Claude state in `/var/lib/genie/tiers/<tier>/claude`,
    and the other tier's directory is inaccessible to it.
- **Token:** the agenix secret `genie-claude-token` is **root**-owned, 0400. A
  genie shell cannot read it by construction. systemd reads it as root for each
  instance's `LoadCredential`, and the instance exports it as
  `CLAUDE_CODE_OAUTH_TOKEN`.
- **Sandbox settings:** the bubblewrap sandbox is on, and commands cannot opt
  out of it.
  - Sandboxed commands may not read the token, `/run/agenix.d`,
    `/run/credentials` or `/proc/*/environ`, and see no
    `CLAUDE_CODE_OAUTH_TOKEN` variable.
  - Claude's own Read tool is denied the token path, `/run/agenix.d`,
    `/run/credentials` and all of `/proc`.

The secret and both instances stay **off** until
`.secrets/hosts/bitstream/genie-claude-token.age` exists in git, and every
bitstream eval prints `genie-expert: genie-claude-token.age is absent` until
then. Hence two deploys: the user and mounts first, then the token.

Run everything from the nix-config devshell on your workstation unless a step
says "on bitstream".

## 0. Pre-checks

Before you start, the branch must be on `main`. The isolation properties are a
flake check, which evaluates bitstream:

```bash
nix build --no-link -L .#checks.x86_64-linux.genie-expert
```

Expected: `genie-expert: 18 properties + settingsDenyRead hold`, exit 0. A
failure prints `genie-expert: failed: <property names>` and exits 1.

Then check that bitstream evaluates as a whole:

```bash
nix eval --raw .#nixosConfigurations.bitstream.config.system.build.toplevel.drvPath
```

Expected: a `/nix/store/...-nixos-system-bitstream-....drv` path and the
`genie-expert: ... absent` warning.

```bash
nix eval --json .#nixosConfigurations.bitstream.config.users.users.genie.extraGroups
nix eval --json .#nixosConfigurations.bitstream.config.fileSystems --apply \
  'fs: builtins.filter (n: builtins.match "/var/lib/genie/.*" n != null && !(builtins.elem "ro" fs.${n}.options)) (builtins.attrNames fs)'
nix eval --json .#nixosConfigurations.bitstream.config.fileSystems --apply \
  'fs: builtins.filter (n: builtins.match "/home/sini/.claude.*" fs.${n}.device != null) (builtins.attrNames fs)'
```

Expected: `[]` for all three. That means no extra groups, every genie mount is
`ro`, and no host mount has a source under `~sini/.claude`.

On bitstream, check the sources. A bind mount keeps the source's permissions, so
genie can read only what is world-readable:

```bash
stat -c '%A %U %n' ~/.claude/memory ~/.claude/memory/*.md | head
ls -d ~/Documents/repos/sini/{den-ag-design,xmsg,matrix-xmsg,gen*}
```

Expected:

- memory is `drwxr-xr-x` and its files are `-rw-r--r--`;
- every checkout named in the `checkouts` setting exists.

A missing checkout fails its own mount unit and does not block boot. Remove it
from the setting, or clone it, before deploying.

## 1. Deploy the user and the mounts

```bash
colmena apply --on bitstream
```

Expected: the deploy succeeds and prints the `genie-expert: ... absent` warning.

Verify on bitstream:

```bash
id genie
findmnt -R /var/lib/genie -o TARGET,SOURCE,OPTIONS
sudo -u genie head -1 /var/lib/genie/repos/gen/README.md
sudo -u genie touch /var/lib/genie/repos/gen/x
ls -A /var/lib/genie/memory
systemctl list-units 'genie-expert@*'
```

Expected:

- `id genie`: `groups=944(genie)` and nothing else;
- `findmnt`: one row per checkout, every one with `ro` in OPTIONS, and **no**
  row for `/var/lib/genie/memory`;
- `head`: prints a line;
- `touch`: `Read-only file system`;
- `ls -A`: empty (the views exist only inside the instances);
- `systemctl list-units`: no units.

**Rollback:** `ssh bitstream sudo nixos-rebuild switch --rollback`. To also drop
genie's state: `sudo rm -rf /persist/var/lib/genie`.

## 2. Create the token secret

The token is genie's own: a long-lived token from `claude setup-token`, used by
no one else and revocable on its own. Mint it in a throwaway config directory so
it touches no existing Claude state:

```bash
d=$(mktemp -d); CLAUDE_CONFIG_DIR=$d claude setup-token; rm -rf "$d"
```

It opens (or prints) a browser URL; finish the login, and it prints the token.
Encrypt it with the YubiKey plugged in. Paste the token into the editor rather
than echoing it, so it stays out of shell history:

```bash
agenix edit .secrets/hosts/bitstream/genie-claude-token.age
git add .secrets/hosts/bitstream/genie-claude-token.age
agenix rekey -a
git add .secrets/hosts/bitstream
git commit -m "bitstream: genie-claude-token"
```

Pre-check: the warning is gone, and both instances evaluate:

```bash
nix eval --json .#nixosConfigurations.bitstream.config.age.secrets.genie-claude-token \
  --apply 's: { inherit (s) owner mode path; }'
nix eval --json .#nixosConfigurations.bitstream.config.systemd.services \
  --apply 's: map (t: s."genie-expert@${t}".serviceConfig.BindReadOnlyPaths) [ "public" "trusted" ]'
```

Expected:

- the secret:
  `{"mode":"0400","owner":"root","path":"/run/agenix/genie-claude-token"}`;
- the binds:
  `[["/var/lib/genie/support-memory:/var/lib/genie/memory"],["/home/sini/.claude/memory:/var/lib/genie/memory"]]`.

**Rollback:** `git revert` the commit, then revoke the token in the Claude
account's settings, where the account lists its long-lived tokens.

## 3. Deploy the expert

```bash
colmena apply --on bitstream
```

Verify on bitstream:

```bash
ls -l /run/agenix/genie-claude-token
systemctl status genie-expert@public genie-expert@trusted
for t in public trusted; do
  sudo nsenter -t "$(systemctl show -p MainPID --value genie-expert@$t)" -m \
    findmnt -o TARGET,SOURCE,OPTIONS /var/lib/genie/memory
done
```

Expected:

- the secret: `-r-------- 1 root root`;
- both units `active (running)`;
- the `nsenter` loop: `public`'s SOURCE is `.../var/lib/genie/support-memory`,
  `trusted`'s is `.../home/sini/.claude/memory`, and both have `ro`. Each
  namespace shows exactly one memory row.

On the first start, attach to each tier and answer Claude's onboarding and
folder-trust prompts once. No login is needed, because the token is in the
environment. Detach with `C-b d`.

```bash
sudo -u genie tmux -S /run/genie-expert-public/tmux.sock attach
sudo -u genie tmux -S /run/genie-expert-trusted/tmux.sock attach
```

**Rollback:**

- Immediate: `sudo systemctl stop genie-expert@public genie-expert@trusted`.
- Durable: `git rm` the `.age`, commit and `colmena apply --on bitstream`. The
  instances and the secret are gated off again, while the user and mounts stay.
- Full: `ssh bitstream sudo nixos-rebuild switch --rollback`.

## 4. Live verification (inside each expert)

Attach to the tier, and ask Claude to run each command with its Bash tool (the
sandboxed path).

On the host, first confirm genie cannot read the token outside any sandbox:

```bash
sudo -u genie cat /run/agenix/genie-claude-token
```

Expected: `Permission denied`.

In **both** tiers:

| command                                                         | expected                      |
| --------------------------------------------------------------- | ----------------------------- |
| `cat /run/agenix/genie-claude-token`                            | fails (denied / no such file) |
| `cat /run/credentials/genie-expert@<tier>.service/claude-token` | fails                         |
| `cat /proc/self/environ`                                        | fails                         |
| `cat /proc/1/environ`                                           | fails                         |
| `echo "${CLAUDE_CODE_OAUTH_TOKEN:-unset}"`                      | `unset`                       |
| `git -C /var/lib/genie/repos/gen log -1 --oneline`              | prints the commit             |
| `touch /var/lib/genie/repos/gen/x`                              | `Read-only file system`       |
| `ls /home/sini`                                                 | fails (`ProtectHome`)         |

Then ask it to **Read** (the Read tool, not Bash)
`/run/agenix/genie-claude-token` and `/proc/self/environ`. Expected: both
refused by permission rules.

In **trusted**:

| command                                   | expected                |
| ----------------------------------------- | ----------------------- |
| `head -3 /var/lib/genie/memory/MEMORY.md` | prints the index        |
| `touch /var/lib/genie/memory/x`           | `Read-only file system` |
| `ls /var/lib/genie/tiers/public`          | `Permission denied`     |

In **public**:

| command                              | expected                                          |
| ------------------------------------ | ------------------------------------------------- |
| `ls -A /var/lib/genie/memory`        | the support-memory contents (empty until curated) |
| `ls /var/lib/genie/memory/MEMORY.md` | no such file (it is not sini's memory)            |
| `ls /var/lib/genie/tiers/trusted`    | `Permission denied`                               |
| `touch /var/lib/genie/memory/x`      | `Read-only file system`                           |

From the public tier's Read tool,
`/proc/<trusted MainPID>/root/var/lib/genie/memory/MEMORY.md` must be refused,
because `Read(//proc/**)` is denied. Get the PID on the host with
`systemctl show -p MainPID --value genie-expert@trusted`.

If any row disagrees, stop both instances (step 3's rollback) and report the row
verbatim.

## Logs

```bash
journalctl -u genie-expert@public -u genie-expert@trusted -f
```

- `Failed to set up credentials` / `LoadCredential`: the secret is missing or
  not rekeyed (`ls -l /run/agenix/genie-claude-token`).
- `Failed to set up mount namespacing` naming `/home/sini/.claude/memory`
  (trusted): the source is absent on bitstream.
- An instance starts and then exits: the tmux server died. Attach fails, and
  `journalctl` shows Claude's own error.
