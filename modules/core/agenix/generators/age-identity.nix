# Generate an age identity keypair.
{
  features.agenix-generators.system =
    { lib, ... }:
    {
      age.generators.age-identity =
        {
          pkgs,
          file,
          ...
        }:
        ''
          publicKeyFile=${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
          ${pkgs.rage}/bin/rage-keygen 2> "$publicKeyFile"
          ${lib.getExe pkgs.gnused} 's/Public key: //' -i "$publicKeyFile"
        '';
    };
}
