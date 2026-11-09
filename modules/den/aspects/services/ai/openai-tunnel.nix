# The OpenAI Secure MCP Tunnel client (pkgs/by-name/tunnel-client) and its runtime key
# (a restricted Platform API key, Tunnels Read + Use only), at a static owner-only path
# for `tunnel-client`'s CONTROL_PLANE_API_KEY. A placed secret, not a generated one: the
# key is issued by OpenAI and was encrypted into the rekeyFile once.
{ rootPath, ... }:
{
  den.aspects.services.ai.openai-tunnel = {
    homeManager =
      { config, pkgs, ... }:
      {
        home.packages = [ pkgs.local.tunnel-client ];

        age.secrets.openai-tunnel-runtime-key = {
          rekeyFile = rootPath + "/.secrets/env/dev/openai/tunnel-runtime-key.age";
          mode = "400";
          path = "${config.home.homeDirectory}/.config/openai-tunnel/runtime-key";
        };
      };
  };
}
