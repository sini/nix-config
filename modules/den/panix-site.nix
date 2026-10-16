# This fleet's settings for the panix battery (batteries/panix.nix): the same
# address/user/tag rules colmena.nix uses. Host selection is the battery
# default (nixos + darwin hosts with a flake output).
{
  den.panix = {
    enable = true;
    flakeName = "nix-config";
    hostAddress =
      host: if host.ipv4 == [ ] then "${host.name}.ts.json64.dev" else builtins.head host.ipv4;
    hostUser = host: host.remote-deployment-user or "sini";
    hostTags = host: [ (host.environment or "prod") ];

    # knownHostsFile stays null: core/network/hostsfile pins peer host keys
    # (names, tailnet name, IPs) in the global known_hosts, which ssh reads
    # alongside the user file. An unpinned target fails closed.

    # No bootstrap is modelled here, so a host inspect misreads as non-NixOS
    # must never be kexec'd + disko'd from this config.
    settings.flags.skip_phases = [ "bootstrap" ];
  };
}
