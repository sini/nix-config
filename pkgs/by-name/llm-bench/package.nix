{ writers }:
writers.writePython3Bin "llm-bench" {
  flakeIgnore = [
    "E501"
    "W503"
  ];
} (builtins.readFile ./llm-bench.py)
