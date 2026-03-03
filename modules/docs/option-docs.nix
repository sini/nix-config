{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      files.files =
        let
          mkOptionDoc = name: options: {
            path_ = "docs/${name}-options.md";
            drv =
              let
                doc = pkgs.nixosOptionsDoc {
                  options = options;
                  warningsAreErrors = false;
                  transformOptions =
                    opt:
                    opt
                    // {
                      default = null;
                      declarations = [ ]; # Keeps the output cleaner for READMEs
                    };
                };
              in
              doc.optionsCommonMark;
          };
        in
        lib.mapAttrsToList mkOptionDoc self.flakeOptions;
    };
}
