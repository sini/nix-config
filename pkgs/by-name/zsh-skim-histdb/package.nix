{
  fetchFromGitHub,
  rustPlatform,
  sqlite,
}:
rustPlatform.buildRustPackage rec {
  pname = "zsh-histdb-skim";
  version = "0.9.7";

  buildInputs = [ sqlite ];
  src = fetchFromGitHub {
    owner = "m42e";
    repo = "zsh-histdb-skim";
    rev = "v${version}";
    hash = "sha256-+wxL95YLlGWLmLFmWETwziRYCtGhtfBXKQQIJQ/oxUk=";
  };

  cargoHash = "sha256-ljB00oZtXA18ukey1nRocmchI72N/DPQrQCEr1Ks13A=";

  patchPhase = ''
    substituteInPlace zsh-histdb-skim-vendored.zsh \
      --replace zsh-histdb-skim "$out/bin/zsh-histdb-skim"
  '';

  postInstall = ''
    mkdir -p $out/share/zsh-histdb-skim
    cp zsh-histdb-skim-vendored.zsh $out/share/zsh-histdb-skim/zsh-histdb-skim.plugin.zsh
  '';
}
