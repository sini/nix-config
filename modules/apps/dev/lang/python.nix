{
  flake.features.python.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        python3
      ];
    };
}
