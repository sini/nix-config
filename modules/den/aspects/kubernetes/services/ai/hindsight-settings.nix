# Settings for the hindsight aspect. Surfaced onto the cluster as
# `cluster.settings.kubernetes.services.ai.hindsight.*`; set per cluster via
# `den.clusters.<name>.settings.kubernetes.services.ai.hindsight.<key>`.
#
# Both point at llama-cpp instances by KEY rather than by URL or model name, so
# the model identity lives in exactly one place — the llama-cpp aspect's
# `instances` — and changing a model there carries here without edits. The
# service address and the `model` string clients must send are both derived.
{ lib, ... }:
{
  # Everything except retain: reflect, consolidation, verification. gpt-oss-20b
  # is rank 2 of 21 on upstream's reflect leaderboard (86.3 against the leader's
  # 86.6, and the leader is gpt-oss-120b which will not fit here). No Qwen model
  # appears on that board at all.
  den.aspects.kubernetes.services.ai.hindsight.settings.defaultLlmInstance = lib.mkOption {
    type = lib.types.str;
    default = "gpt-oss";
    description = ''
      Key into `kubernetes.services.ai.llama-cpp.instances` serving the default
      LLM for every operation without its own override.
    '';
  };

  # Same instance as the default for now, which collapses the split: when this
  # equals defaultLlmInstance the aspect emits no HINDSIGHT_API_RETAIN_LLM_*
  # at all and every operation runs on one model.
  #
  # The leaderboard argues for Qwen3.6 35B-A3B here — it leads the open-weight
  # retain field at quality 59.5 (49%) against gpt-oss 20B's 56.3 (48%). First
  # contact on this hardware did not bear that out: extracting from a 136-char
  # document took Qwen 104s and 2121 output tokens for ONE memory unit, where
  # gpt-oss took 179 output tokens for TWO from a comparable input. Not hidden
  # reasoning — thoughts_tokens was 0 and raw completions showed empty <think>
  # blocks — just verbosity that bought nothing.
  #
  # Two documents is not a sample, and the leaderboard is a real measurement
  # against a real benchmark, so this is provisional rather than a refutation.
  # Set this to "qwen" to restore the split; the instance stays deployed.
  den.aspects.kubernetes.services.ai.hindsight.settings.retainLlmInstance = lib.mkOption {
    type = lib.types.str;
    default = "cortex-cuda";
    description = ''
      Key into `kubernetes.services.ai.llama-cpp.instances` serving the retain
      (fact-extraction) path, via HINDSIGHT_API_RETAIN_LLM_*. When equal to
      defaultLlmInstance the per-operation override is omitted entirely.
    '';
  };

  # Off-cluster OpenAI-compatible endpoints, addressable by the same instance
  # keys as llama-cpp. Kept as explicit settings rather than derived from the
  # ninfer-endpoints quirk: that quirk is host-scoped, so reaching it would need
  # a cluster-scoped collect policy crossing the dev/prod boundary for a single
  # address — more machinery than the fact is worth, and it would hide the
  # cross-environment dependency rather than state it.
  #
  # Each entry also carries the CIDR its egress policy needs: in-cluster traffic
  # rides the clusterwide allow-internal-egress policy, but anything off-cluster
  # must be named explicitly or Cilium's default-deny drops it.
  den.aspects.kubernetes.services.ai.hindsight.settings.externalLlms = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          url = lib.mkOption {
            type = lib.types.str;
            description = "OpenAI-compatible base URL, including /v1.";
          };
          model = lib.mkOption {
            type = lib.types.str;
            description = ''
              Model id the endpoint answers to. ninfer REJECTS a request whose
              `model` field is not exactly its --model-id, so this is not
              cosmetic.
            '';
          };
          cidr = lib.mkOption {
            type = lib.types.str;
            description = "Host CIDR for the egress CiliumNetworkPolicy.";
          };
          port = lib.mkOption {
            type = lib.types.port;
            description = "Port for the egress CiliumNetworkPolicy.";
          };
        };
      }
    );
    default = {
      # Both entries are the ONE RTX 3090 Ti on cortex-cuda, which holds a single
      # engine at a time (they declare Conflicts= over the card). Reachable from
      # the cluster only since the UniFi prod->dev rule plus the 10.9.2.0/24
      # static route.
      #
      # STANDING CAVEAT on both: this is a guest on a DEV-environment workstation
      # (roles.gaming, roles.dev-gui). Prod work pointed here queues behind
      # interactive use and stops when the machine reboots.

      # The resident engine, and the reason this host is worth pointing at: the
      # SAME gpt-oss-20b the in-cluster instances serve, under the SAME alias, so
      # selecting it changes which GPU answers rather than which model does.
      # reasoning_effort is pinned low server-side in services.ai.llama-cpp,
      # which is the retain-shaped setting — retain is prefill-bound extraction,
      # so thinking is latency that buys nothing.
      gpt-oss-cortex = {
        url = "http://10.9.2.2:8080/v1";
        model = "gpt-oss-20b";
        cidr = "10.9.2.2/32";
        port = 8080;
      };

      # Same card, other engine, other model. Faster per stream — 96.2 tok/s
      # decode against llama-cpp's 45.5 on identical prompts — but no longer
      # resident: since llama-cpp took autostart this needs an explicit
      # `systemctl start ninfer` on the guest, which evicts llama-cpp.
      ninfer = {
        url = "http://10.9.2.2:8081/v1";
        model = "qwen3.8-27b";
        cidr = "10.9.2.2/32";
        port = 8081;
      };

      # Same host, same GPU, DIFFERENT SERVER. cortex-cuda now also runs
      # llama-cpp with gpt-oss-20b on 8080 beside ninfer on 8081.
      #
      # ★ THIS ONE CAN SERVE RETAIN AND ninfer CANNOT, for one reason: fact
      # extraction requests STRUCTURED OUTPUT. ninfer's request validator
      # rejects any non-text response_format by design — src/serve/
      # openai_schema.cpp:439 with tests/test_openai_schema.cpp asserting
      # "json response_format rejected" — so it is a code-level gap, not a
      # flag. llama-cpp constrains decoding to a schema, and both
      # json_schema and json_object return 200 here (measured 2026-09-02,
      # 1.8s for 4563 prompt tokens).
      #
      # Same MODEL as the in-cluster pool, so pointing retain here changes
      # WHERE extraction runs, never what the corpus was extracted by.
      cortex-cuda = {
        url = "http://10.9.2.2:8080/v1";
        model = "gpt-oss-20b";
        cidr = "10.9.2.2/32";
        port = 8080;
      };
    };
    description = ''
      Off-cluster LLM endpoints selectable by defaultLlmInstance /
      retainLlmInstance, in the same key space as llama-cpp.instances.
    '';
  };
}
