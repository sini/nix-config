# genie-experts: the Claude subscription token pool for genie's expert pods
# (I10.3). One file per account, `claude setup-token` output, minted by its owner
# (no generator), under the tier that may spend it:
#
#   .secrets/env/prod/genie-experts/<tier>/<label>.age
#     trusted/  the owner's accounts only
#     public/   contributors' accounts, and the owner's under a daily cap
#
# The pool is the directory listing: adding a file shares a token, `git rm` stops
# it. <label> names the account neutrally, never by its email. Each file becomes
# the key `<tier>-<label>` of the `genie-experts` sops store, ready for a
# SopsSecret once an expert pod consumes it; nothing does yet.
{ lib, rootPath, ... }:
let
  pool = rootPath + "/.secrets/env/prod/genie-experts";
  tiers = [
    "trusted"
    "public"
  ];

  tokensIn =
    tier:
    let
      dir = pool + "/${tier}";
      files = lib.optionalAttrs (builtins.pathExists dir) (builtins.readDir dir);
    in
    map (f: {
      inherit tier;
      label = lib.removeSuffix ".age" f;
      rekeyFile = dir + "/${f}";
    }) (lib.filter (f: files.${f} == "regular" && lib.hasSuffix ".age" f) (lib.attrNames files));
in
{
  den.aspects.kubernetes.services.ai.genie-experts.age-secrets = _: {
    age.secrets = lib.listToAttrs (
      map (t: {
        name = "genie-experts-${t.tier}-${t.label}";
        value = {
          inherit (t) rekeyFile;
          sopsOutput = {
            file = "genie-experts";
            key = "${t.tier}-${t.label}";
          };
        };
      }) (lib.concatMap tokensIn tiers)
    );
  };
}
