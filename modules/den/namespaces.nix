{
  inputs,
  den,
  ...
}:
{
  imports = [
    # You can have several namespaces,
    # - true: exposes flake.denful.yours
    # - false: Not flake exposed.

    # You can also mixin from several inputs.
    # Just keep in mind that a namespace can be defined only once, use an array as argument:
    # (inputs.den.namespace "ours" [
    #   true
    #   inputs.mine
    #   inputs.theirs
    # ])
    (inputs.den.namespace "sini" true)
  ];

  # you can have more than one namespace, create yours.
  # imports = [ (inputs.den.namespace "yours" true) ];

  # you can also import namespaces from remote flakes.
  # imports = [ (inputs.den.namespace "ours" inputs.theirs) ];

  # this line enables den angle brackets syntax in modules.
  _module.args.__findFile = den.lib.__findFile;
}
