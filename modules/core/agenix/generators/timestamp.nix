# Generate a timestamp.
{
  features.agenix-generators.system = _: {
    age.generators.timestamp = _: ''
      date +%FT%T%Z
    '';
  };
}
