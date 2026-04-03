{ den, ... }:
{
  den.aspects.k9s = den.lib.perUser {
    homeManager =
      {
        pkgs,
        config,
        ...
      }:
      {
        home.packages = with pkgs; [
          k9s
        ];
        home.sessionVariables.KUBECONFIG = "${config.xdg.configHome}/kube/config";
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
  };
}
