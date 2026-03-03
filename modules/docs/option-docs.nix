{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      files.files = [
        {
          path_ = "docs/options.md";
          drv =
            let
              doc = pkgs.nixosOptionsDoc {
                options = self.flakeOptions;
                warningsAreErrors = false;
              };
            in
            doc.optionsCommonMark;
        }
      ];
    };
}
