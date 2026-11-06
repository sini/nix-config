{
  den.aspects.applications.dev.k8s.k9s = {
    homeManager =
      {
        pkgs,
        config,
        ...
      }:
      {
        home.packages = [
          pkgs.k9s
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

    # The kubeconfig KUBECONFIG points at, and k9s's own state.
    persistHome.directories = [
      ".config/kube"
      ".local/share/k9s"
      ".local/state/k9s"
    ];

    cacheHome.directories = [
      ".kube"
    ];
  };
}
