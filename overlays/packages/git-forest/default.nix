{
  stdenv,
  lib,
  flakeVersion,
  perl,
  makeWrapper,
  perl538Packages,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "git-forest";
  version = flakeVersion;

  src = ./.;

  buildInputs = [perl];
  nativeBuildInputs = [makeWrapper];
  installPhase = ''
    install -Dm755 git-forest.pl $out/bin/git-forest
  '';
  postFixup = ''
    wrapProgram $out/bin/git-forest \
    --prefix PERL5LIB : "${with perl538Packages; makePerlPath [Git Error]}"
  '';

  meta = {
    description = "git-forest, nicer way to see commit-history tree";
    homepage = "https://github.com/aarnphm/dix";
    maintainers = with lib.maintainers; [aarnphm];
    platforms = lib.platforms.unix;
  };
})
