################################################################################
# A agenix-rekey generator for using a template to substitute secrets into a
# file that itself is also considered secret.
#
# This generator takes advantage of the un-merged settings feature in
# agenix-rekey.
#
# The settings structure expected is:
# {
#   template: String;
# }
# or
# {
#   templateFile: String;
# }
# The dependencies pulled in will substitute based on their name.
# The template string is in the form of %name% but one day I may make that
# configurable.
################################################################################
{
  features.agenix-generators.system =
    { lib, ... }:
    {
      age.generators.template-file =
        {
          decrypt,
          deps,
          pkgs,
          secret,
          ...
        }:
        let
          template = secret.settings.template or (builtins.readFile secret.settings.templateFile);
        in
        ''
          printf '%s' ${lib.escapeShellArg template} \
            ${lib.strings.concatStringsSep " " (
              map (dep: ''
                | ${pkgs.replace}/bin/replace-literal \
                  -e \
                  -f \
                  "%${lib.escapeShellArg dep.name}%" \
                  "$(${decrypt} ${lib.escapeShellArg dep.file})" \
              '') deps
            )}
        '';
    };
}
