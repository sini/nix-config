# Hermes Agent (https://hermes-agent.nousresearch.com, github:NousResearch/hermes-agent):
# Autonomous terminal AI agent harness configured for local high-context inference.
{ ... }:
{
  den.aspects.applications.dev.ai.hermes = {
    homeManager =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        hermesPkg = pkgs.local.hermes-agent or pkgs.hermes-agent or null;

        # Declarative configuration for Hermes Agent
        hermesConfig = {
          model = {
            provider = "custom";
            baseUrl = "http://10.9.2.2:8080/v1";
            default = "qwen3.8-27b-instruct";
            contextWindow = 819200; # 800K context window matching local llama-cpp setup
            maxTokens = 32768;
            reasoning = true;
            thinkingLevel = "medium";
          };
          compaction = {
            enabled = true;
            reserveTokens = 14000;
            keepRecentTokens = 20000;
          };
          security = {
            defaultProjectTrust = "never";
          };
          localProxy = {
            ollamaBaseUrl = "http://10.9.2.2:11434/v1";
            llamaCppBaseUrl = "http://10.9.2.2:8080/v1";
          };
        };
      in
      {
        home.packages = lib.optionals (hermesPkg != null) [
          hermesPkg
        ];

        programs.git.ignores = [
          "/.hermes/"
        ];

        # Declarative Hermes Agent config.yaml
        home.file.".hermes/config.yaml".text = builtins.toJSON hermesConfig;

        # Declarative Hermes Agent cli-config.yaml
        home.file.".hermes/cli-config.yaml".text = builtins.toJSON hermesConfig;
      };

    persistHome = {
      directories = [
        ".hermes"
      ];
    };
  };
}
