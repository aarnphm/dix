{ config, pkgs, ... }:

let
  go = pkgs.callPackage ./go.nix { };
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
      go
      pkgs.jq
      pkgs.llvm
      pkgs.ninja
      pkgs.tree
      pkgs.wget
      pkgs.zip
      pkgs.pstree
      pkgs.enchant
      pkgs.vscode
    ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  # nix.package = pkgs.nix;

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
