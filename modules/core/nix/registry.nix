{
  features.nix.system =
    {
      config,
      inputs,
      lib,
      ...
    }:
    {
      nix = {
        # TODO: figure this out
        # This will add each flake input as a registry
        # To make nix3 commands consistent with your flake
        # registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

        # This will add your inputs to the system's legacy channels
        # Making legacy nix commands consistent as well
        # nixPath =
        #   config.nix.registry
        #   # nixfmt hack
        #   |> lib.mapAttrsToList (key: value: "${key}=${value.to.path}");
      };
    };
}
