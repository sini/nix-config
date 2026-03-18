# Generate htpasswd entries from secret dependencies.
{
  flake.features.agenix-generators.system =
    { lib, ... }:
    {
      age.generators.htpasswd =
        {
          decrypt,
          deps,
          pkgs,
          secret,
          ...
        }:
        # htpasswd flags:
        #   -n: output to stdout.
        #   -i: read password from stdin.
        #   -B: bcrypt hashing.
        #   -C: bcrypt cost factor.
        # htpasswd outputs "username:hash\n" to stdout.  Use printf to avoid the
        # heredoc adding an extra trailing newline.
        lib.strings.concatMapStrings (
          { file, ... }:
          "printf '%s\\n' \"$(${decrypt} ${lib.escapeShellArg file} "
          + "| ${pkgs.apacheHttpd}/bin/htpasswd -niBC 10 "
          + "${lib.escapeShellArg secret.settings.username})\"; "
        ) deps;
    };
}
