{ config, pkgs, ... }:

let
  go = pkgs.callPackage ./go.nix { };
  postgresql = pkgs.postgresql_14;
in
{
  nixpkgs.config.allowUnfree = true;
  environment.variables = { EDITOR = "neovim"; };
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages =
    [
      pkgs.neovim
      pkgs.vim
      pkgs.tmux
      pkgs.jdk
      pkgs.jre
      pkgs.openjdk17
      pkgs.asciinema
      pkgs.ccls
      pkgs.fd
      pkgs.fzf
      pkgs.git
      pkgs.gnupg
      # golang
      pkgs.jq
      pkgs.llvm
      pkgs.ninja
      pkgs.tree
      pkgs.wget
      pkgs.zip
      pkgs.pstree
      pkgs.bazel_5
      pkgs.enchant
      pkgs.vscode
      pkgs.cmake
      pkgs.gcc
      pkgs.pkg-config
      pkgs.swig
      pkgs.openssl_3_0
      pkgs.colima
      pkgs.skopeo
      pkgs.nnn
      # kubernetes
      pkgs.minikube
      pkgs.kubernetes
      pkgs.kubernetes-helm
      pkgs.ngrok
      pkgs.buildkit
      postgresql
      pkgs.direnv
      pkgs.nixFlakes
      pkgs.niv
    ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  services.postgresql.enable = true;
  services.postgresql.package = postgresql;
  services.postgresql.dataDir = "/data/postgresql";
}
