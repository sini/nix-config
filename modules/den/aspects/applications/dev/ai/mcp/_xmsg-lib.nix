# Helpers shared by the aspects that run an xmsg federation node: login users'
# (xmsg.nix) and services' (services/matrix-xmsg.nix). Imported, not auto-loaded.
{ lib, self }:
rec {
  # User pairs whose nodes federate across the two users (policies/xmsg.nix), and the
  # only cross-user reach a service node may have (mcp/xmsg.nix asserts it).
  trustedPairs = [
    # vic can already take over sini's sessions (herdr-pair); messaging is no more.
    [
      "sini"
      "vic"
    ]
  ];
  trusts = a: b: a == b || lib.any (pair: lib.elem a pair && lib.elem b pair) trustedPairs;

  caDir = self + "/.secrets/xmsg-ca";
  spiffeOf = host: user: "spiffe://json64.dev/host/${host}/user/${user}";
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
        uri = spiffeOf host.name user;
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
