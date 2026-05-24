{ den, lib, ... }:
{
  den.classes.homeLinux.description = "Home-manager modules for Linux hosts";
  den.classes.homeDarwin.description = "Home-manager modules for Darwin hosts";
  den.classes.homeAarch64.description = "Home-manager modules for aarch64 hosts";

  den.policies.homeLinux-to-hm =
    { host, ... }:
    lib.optional (lib.hasSuffix "-linux" host.system) (
      den.lib.policy.route {
        fromClass = "homeLinux";
        intoClass = "homeManager";
        path = [ ];
      }
    );

  den.policies.homeDarwin-to-hm =
    { host, ... }:
    lib.optional (lib.hasSuffix "-darwin" host.system) (
      den.lib.policy.route {
        fromClass = "homeDarwin";
        intoClass = "homeManager";
        path = [ ];
      }
    );

  den.policies.homeAarch64-to-hm =
    { host, ... }:
    lib.optional (lib.hasPrefix "aarch64-" host.system) (
      den.lib.policy.route {
        fromClass = "homeAarch64";
        intoClass = "homeManager";
        path = [ ];
      }
    );

  # Route policies fire at user scope where host.system is available
  den.schema.user.includes = [
    den.policies.homeLinux-to-hm
    den.policies.homeDarwin-to-hm
    den.policies.homeAarch64-to-hm
  ];
}
