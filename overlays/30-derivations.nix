self: super:
let
  dixPackages = {
    editor = {
      name = "editor";
      src = super.dix.editor-nix;
      version = self.flakeVersion super.dix.editor-nix;
    };
    emulators = {
      name = "emulators";
      src = super.dix.emulator-nix;
      version = self.flakeVersion super.dix.emulator-nix;
    };
  };
in
{
  nvtop-appl = super.callPackage ./packages/nvtop-appl { };

  dix = super.dix or { } // {
    openllm-ci = super.callPackage ./packages/bentoml/openllm-ci { };
    aws-credentials = super.callPackage ./packages/aws-credentials { };
    unicopy = super.callPackage ./packages/unicopy { };
    git-forest = super.callPackage ./packages/git-forest { };
    zsh-dix = super.callPackage ./packages/zsh-dix { };
    bitwarden-cli = super.callPackage ./packages/bitwarden-cli { };
    paperspace-cli = super.callPackage ./packages/paperspace-cli { };
    pinentry-touchid = super.callPackage ./packages/pinentry-touchid { };
  } // super.lib.mapAttrs (name: { src, version, ... }: self.mkDerivationKeepSrc { inherit name src version; }) dixPackages;
}
