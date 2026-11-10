# Helpers shared by the aspects that run an xmsg federation node: login users'
# (xmsg.nix) and services' (services/matrix-xmsg.nix). Imported, not auto-loaded.
{ lib, self }:
rec {
  # The users whose nodes federate with `name`'s across the two users (policies/xmsg.nix),
  # and the only cross-user reach a service node may have (mcp/xmsg.nix asserts it): each
  # user's `xmsg.trusts` (den.users.registry), read both ways.
  partnersOf =
    users: name:
    lib.remove name (
      lib.unique (
        (users.${name}.xmsg.trusts or [ ])
        ++ lib.attrNames (lib.filterAttrs (_: u: lib.elem name (u.xmsg.trusts or [ ])) users)
      )
    );
  trusts = users: a: b: a == b || lib.elem b (partnersOf users a);

  caDir = self + "/.secrets/xmsg-ca";
  # `domain` is the trust domain: the node's environment domain.
  spiffeOf = domain: host: user: "spiffe://${domain}/host/${host}/user/${user}";
  # A node's name derives from its identity (xmsg README 7.0): `<user>.<host>` for a host,
  # `<sa>.<ns>` for a pod. A CA peer entry must be keyed by it.
  nodeName = host: user: "${user}.${host}";
  leafName = user: "xmsg-${user}-fed-ca";

  # A committed .crt sidecar, refused by name until generated. Copied alone, so a
  # path under `self` does not pull the whole flake source into the store path.
  caCrt =
    crt:
    if builtins.pathExists crt then
      builtins.path {
        path = crt;
        name = builtins.unsafeDiscardStringContext (baseNameOf crt);
      }
    else
      throw ''
        xmsg federation: ${toString crt} is absent. Declare the node, then run
        `agenix generate`, `git add` the .age and .crt files, and `agenix rekey`.
      '';

  # The CA-signed leaf a node presents: its spiffe identity, from the host intermediate.
  leafSecret =
    {
      config,
      domain,
      host,
      user,
    }:
    {
      rekeyFile = host.secretPath + "/${leafName user}.age";
      generator = {
        script = "x509-spiffe-leaf";
        dependencies = [
          config.age.secrets.xmsg-ca-host-intermediate
          config.age.secrets.xmsg-ca-root
        ];
      };
      settings = {
        cn = "${user}@${host.name}";
        uri = spiffeOf domain host.name user;
      };
      owner = user;
      mode = "0400";
    };

  # A peer entry for another node, trusting the root with that node's one identity.
  caPeer = rootCa: allow: p: {
    inherit (p) address;
    inherit allow;
    ca = rootCa;
    identities = [ p.identity ];
  };
}
