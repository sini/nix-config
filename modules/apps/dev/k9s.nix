{

  flake.features.k9s.home =
    { pkgs, config, ... }:
    {
      home.packages = with pkgs; [
        kubelogin
        kubectl
        k9s
      ];
      # TODO: Each cluster specified in separate `.nix` files, each appending their config to this env var.
      # TODO: Figure out if Nix's module merging can handle colon-separated strings.
      # TODO: Consider `XDG_DATA_HOME` vs `XDG_CONFIG_HOME` (possible to prevent secret auth data from being stored in `~/.config`?
      home.sessionVariables.KUBECONFIG = "${config.xdg.configHome}/kube/config";
      # https://k9scli.io/
      # https://k9scli.io/topics/config/
      # https://github.com/derailed/k9s/tree/master
      programs.k9s = {
        enable = true;
        settings = {
          k9s = {
            refreshRate = 5;
            maaConnRetry = 15;
            enableMouse = true;
            headless = true;
            crumbsless = true;
            readOnly = false;
            logger = {
              tail = 200;
              buffer = 1000;
              sinceSeconds = 600;
              fullScreenLogs = false;
              textWrap = false;
              showTime = false;
            };

          };
        };
      };
    };
}
