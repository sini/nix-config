# Runbook: per-tier xmsg instances on bitstream (I16)

The aspect `services.ai.genie-xmsg`
(`modules/den/aspects/services/ai/genie-xmsg.nix`) gives each genie tier its own
xmsg bus, `xmsg@public` (as `genie-public`) and `xmsg@trusted` (as
`genie-trusted`), beside `sini`'s user service.

- Each serves HTTP only on `/run/xmsg-<tier>/xmsg/http.sock`: the `xmsg/`
  directory 0700, the socket 0600, and a peer-uid check. A process reaches only
  its own user's bus.
- `/run/xmsg-<tier>` is the unit's `RuntimeDirectory=` (0700, the tier user,
  preserved across a restart), and the unit's `XDG_RUNTIME_DIR`. I10.2's
  `genie-herdr@` and `genie-dispatcher@` read the path from
  `services.genie-xmsg.runtimeDir`.
- Neither tier instance binds TCP. The render refuses a `--listen` or
  `XMSG_LISTEN` on either, and `nix build .#checks.x86_64-linux.genie-xmsg`
  asserts it over the rendered units.
- The reply store is `/var/lib/xmsg-<tier>/xmsg.db`, persisted.
- **Inert until X1:** the fed ports (`sini` 7788, `genie-public` 7789,
  `genie-trusted` 7790), the node keys and the links. Nothing passes them to
  xmsg yet.
- **Inert until X9:** `settings.<tier>.svcTrustedExes`.
- **Empty until I10.3:** `settings.<tier>.sessionsDirs`. Without it, xmsg reads
  `~/.claude/sessions` of the tier user.

**No xmsg instance listens on TCP**, `sini`'s included. The bot reaches `sini`'s
bus through `http.sock` (matrix-xmsg M13.1) and xmsg-pi's `list` tool defaults
to it (xmsg X15).

## 1. Node keys (optional before X1)

Set `settings.services.ai.genie-xmsg.nodeKeys = true;` in
`modules/den/hosts/bitstream.nix`, then:

```bash
agenix generate
git add .secrets/hosts/bitstream/xmsg-genie-{public,trusted}.{age,crt}
agenix rekey
```

Each key lands at `/run/agenix/xmsg-genie-<tier>`, owned by its tier user
at 0400.

## 2. Deploy

```bash
colmena apply --on bitstream
```

This also restarts `sini`'s `xmsg` user service on the bumped binary.

## 3. Live probes (design oracle 29)

On bitstream:

```bash
# The units and the three layers' modes.
systemctl status xmsg@public xmsg@trusted
sudo stat -c '%a %U %n' /run/xmsg-{public,trusted} /run/xmsg-{public,trusted}/xmsg \
  /run/xmsg-{public,trusted}/xmsg/http.sock
# ⇒ 700 genie-<tier> for both directories, 600 genie-<tier> for the socket

# Positive control: each tier reaches its own bus.
for t in public trusted; do
  sudo -u genie-$t curl -s --unix-socket /run/xmsg-$t/xmsg/http.sock http://localhost/healthz
done

# Cross-tier: refused both ways, and from sini.
sudo -u genie-public curl -s --unix-socket /run/xmsg-trusted/xmsg/http.sock http://localhost/healthz
sudo -u genie-trusted curl -s --unix-socket /run/xmsg-public/xmsg/http.sock http://localhost/healthz
curl -s --unix-socket /run/xmsg-trusted/xmsg/http.sock http://localhost/healthz
# ⇒ each: curl (7) Couldn't connect / Permission denied

# One layer at a time: relax the directory and the socket; the peer-uid check
# alone must still refuse.
sudo chmod 0755 /run/xmsg-trusted /run/xmsg-trusted/xmsg
sudo chmod 0666 /run/xmsg-trusted/xmsg/http.sock
sudo -u genie-public curl -s --unix-socket /run/xmsg-trusted/xmsg/http.sock http://localhost/healthz
# ⇒ the connection is closed with no HTTP response
sudo chmod 0700 /run/xmsg-trusted /run/xmsg-trusted/xmsg
sudo chmod 0600 /run/xmsg-trusted/xmsg/http.sock
sudo systemctl restart xmsg@trusted

# TCP: no xmsg listener except, after X1, the fed listeners on 7788-7790.
sudo ss -ltnp | grep xmsg
```

The bot still delivers: mention `@genie` in `#support:json64.dev` as `@json`,
then check that the reply posts and that `journalctl -u matrix-xmsg` shows no
`POST … failed`.

**Not here:** the uid-check-removed mutant is an xmsg cell (X8). The reply-only
MCP cell and the within-tier deny cell belong to I10.2.

## 4. Rollback

```bash
ssh bitstream.ts.json64.dev sudo nixos-rebuild switch --rollback
```

Or revert the commit and deploy again. The rollback stops both tier units and
restores `sini`'s xmsg to the previous binary. `/run/xmsg-<tier>` goes at the
next reboot, or with `sudo rm -rf /run/xmsg-{public,trusted}`.
`/var/lib/xmsg-<tier>` persists until it is removed from `/persist`.
