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
                      # Optional: Hide the type if it's just 'submodule' to save space
                      type = if opt.type == "submodule" then null else opt.type;
                    };
                };
              in
              doc.optionsCommonMark;
          };
        in
        lib.mapAttrsToList mkOptionDoc self.flakeOptions;
    };
}
