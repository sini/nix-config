# Generate a Nix binary cache signing keypair.
{
  flake.features.agenix-generators.system =
    {
      config,
      lib,
      ...
    }:
    {
      age.generators.binary-cache-key =
        {
          pkgs,
          file,
          ...
        }:
        let
          keyName = "${config.networking.fqdn}";
        in
        ''
          publicKeyFile=${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
          tmpdir=$(mktemp -d)
          trap 'rm -rf "$tmpdir"' EXIT
          ${pkgs.nix}/bin/nix-store --generate-binary-cache-key \
            ${lib.escapeShellArg keyName} \
            "$tmpdir/private.pem" \
            "$publicKeyFile"
          cat "$tmpdir/private.pem"
        '';
    };
}
