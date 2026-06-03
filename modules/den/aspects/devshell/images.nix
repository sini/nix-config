# OCI/Helm image update devshell commands emitted via class routing.
{ den, ... }:
{
  den.aspects.devshell.images = {
    devshell =
      { self', inputs', ... }:
      {
        commands = [
          {
            name = "helmupdater";
            command = ''${inputs'.nixhelm.packages.helmupdater}/bin/helmupdater "$@"'';
            help = "Update helm chart versions and hashes";
          }
          {
            package = self'.packages.oci-image-updater;
            name = "oci-image-updater";
            help = "Update OCI container image versions and hashes";
          }
        ];
      };
  };
  den.schema.flake-parts.includes = [ den.aspects.devshell.images ];
}
