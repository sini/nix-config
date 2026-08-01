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

  # Written as a policy record rather than a bare function so it can carry `emits`. The
  # route is value-conditional on `host.system` — the third arm of the same family as the
  # two above — so a body fired at a sentinel whose system carries no aarch64 prefix takes
  # the false branch and emits nothing. The delivery codomain therefore cannot be observed
  # by firing, and the recovered empty head is not merely uninformative: the `delivery`
  # this body does emit at a real aarch64 host would abort against it.
  #
  # The linux and darwin arms are covered by den-compat's v1-name table; this one belongs
  # here instead, because a declaration on the source record is consulted before that
  # table, and which kinds a corpus policy produces is a fact the corpus owns.
  den.policies.homeAarch64-to-hm = {
    __isPolicy = true;
    emits = [ "delivery" ];
    fn =
      { host, ... }:
      lib.optional (lib.hasPrefix "aarch64-" host.system) (
        den.lib.policy.route {
          fromClass = "homeAarch64";
          intoClass = "homeManager";
          path = [ ];
        }
      );
  };

  # Route policies fire at user scope where host.system is available
  den.schema.user.includes = [
    den.policies.homeLinux-to-hm
    den.policies.homeDarwin-to-hm
    den.policies.homeAarch64-to-hm
  ];
}
