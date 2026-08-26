# Independent aspect providing local LLM & substrate benchmarking tools
# (sysbench, iperf3, dmidecode, llama-cpp).
#
# Deliberately NOT included in any default role — include explicitly on target host aspects:
#   includes = with den.aspects; [ services.ai.benchmarking ];
{ ... }:
{
  den.aspects.services.ai.benchmarking = {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.sysbench
          pkgs.iperf3
          pkgs.dmidecode
          pkgs.llama-cpp
        ];
      };
  };
}
