# Generate a timestamp.
{
  flake.features.agenix-generators.system = _: {
    age.generators.timestamp = _: ''
      date +%FT%T%Z
    '';
  };
}
