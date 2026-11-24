{
  lib,
  runCommand,
  makeWrapper,
  python3,
  git,
  openssh,
  coreutils,
}:
runCommand "peer-sync"
  {
    nativeBuildInputs = [ makeWrapper ];
    meta = {
      description = "Mirror a host's git refs to a peer so in-flight work is transferable between machines";
      mainProgram = "peer-sync";
    };
  }
  ''
    install -Dm755 ${./peer-sync.py} $out/libexec/peer-sync.py
    substituteInPlace $out/libexec/peer-sync.py --replace-fail '#!/usr/bin/env python3' '#!${python3.interpreter}'
    ${python3.interpreter} -m py_compile $out/libexec/peer-sync.py
    rm -rf $out/libexec/__pycache__
    # openssh is a SUFFIX: the ssh already on PATH (the user's, or the check's fake
    # remote) wins, and the pinned one is the fallback.
    makeWrapper $out/libexec/peer-sync.py $out/bin/peer-sync \
      --prefix PATH : ${
        lib.makeBinPath [
          git
          coreutils
        ]
      } \
      --suffix PATH : ${lib.makeBinPath [ openssh ]}
  ''
