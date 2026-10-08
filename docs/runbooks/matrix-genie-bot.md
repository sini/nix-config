# Runbook: bring up the `@genie` support bot

`@genie:json64.dev` ([matrix-xmsg](https://github.com/sini/matrix-xmsg)) answers
mentions in a public support room by relaying them to an expert agent session
through xmsg on **bitstream**. The aspect is `services.matrix-xmsg`
(`modules/den/aspects/services/matrix-xmsg.nix`):

- trusted senders are kanidm's `admins` group (`idm-users`, filtered to the
  environment whose kanidm serves bitstream's), so trust follows kanidm;
- the expert is the xmsg session `genie-support` (setting `expertRef`);
- the service stays **off** while `settings.services.matrix-xmsg.rooms` is
  empty, and every bitstream eval prints a warning saying so.

Do the steps in order: setting `rooms` before the token secret exists fails eval
with `age.secrets.matrix-genie-token.rekeyFile ... doesn't exist`.

## 1. Create the room

From `@json` (Element), create a **public** room with the address
`#support:json64.dev`.

## 2. Provision the bot

From the nix-config devshell, with the YubiKey plugged in and `kubectl` pointed
at the axon cluster:

```bash
matrix-bot-provision '#support:json64.dev'
```

It port-forwards `svc/synapse` (namespace `matrix`), decrypts the registration
shared secret with the YubiKey, registers `@genie` (not an admin, throwaway
password), encrypts the access token to
`.secrets/hosts/bitstream/matrix-genie-token.age` with the master recipients and
stages it, then resolves the alias, joins it, and prints the setting line.

- Re-running once the `.age` exists skips registration and only joins, so a
  failed join is fixed by running it again.
- `@genie already exists` (`M_USER_IN_USE`) with no `.age`: the token is gone.
  Restore the `.age` from git history, or mint a token through the admin API
  (`POST /_synapse/admin/v1/users/@genie:json64.dev/login`), encrypt it there,
  and re-run.

## 3. Set `rooms`

In `modules/den/hosts/bitstream.nix`, under
`den.hosts.x86_64-linux.bitstream.settings`, add the line the command printed:

```nix
services.matrix-xmsg.rooms = [ "!<id>:json64.dev" ];
```

## 4. Rekey and commit

```bash
agenix rekey -a
git add .secrets/hosts/bitstream modules/den/hosts/bitstream.nix
git commit -m "bitstream: enable the @genie support bot"
```

## 5. Deploy bitstream

```bash
colmena apply --on bitstream
```

## 6. Start the expert session

On bitstream, as `sini` (xmsg is that user's service on `127.0.0.1:7787`):

```bash
mkdir -p ~/genie-support && cd ~/genie-support && pi
```

The xmsg pi extension registers it under the cwd basename, `genie-support`.

## 7. Smoke test

In `#support:json64.dev`, as `@json`, send a message mentioning `@genie`. The
question reaches the pi session; its reply is posted back in the room.

## Logs

```bash
journalctl -u matrix-xmsg -f
```

- token or credential errors at start: the agenix secret is missing or was not
  rekeyed (`ls -l /run/agenix/matrix-genie-token`);
- the room is not allowlisted, or the sender is not trusted: check `rooms`, and
  that the sender is in kanidm's `admins` group;
- xmsg connection refused: the `xmsg` user service is down
  (`systemctl --user status xmsg` as `sini`);
- the expert is not found or the answer times out (300 s, then the owner is
  notified): the pi session in `~/genie-support` is not running.
