{ pkgs, user, lib, inputs, ... }:
let
  env = import ../dix { inherit pkgs lib; };
in
{
  imports = [ ./modules ];

  environment.systemPackages = env.packages;
  environment.variables = env.variables;

  # Users
  users.users.${user} = {
    shell = pkgs.zsh;
    home = "/Users/${user}";
    createHome = true;
  };

  environment.shells = with pkgs; [ zsh ];

  nix.package = pkgs.nix;
  nix.settings = {
    auto-optimise-store = true;
    experimental-features = "nix-command flakes";
    trusted-users = [ "root" "aarnphm" ];
  };

  nix.gc = {
    automatic = true;
    interval.Hour = 3;
    options = "--delete-older-than 7d --max-freed $((25 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";
  };

  skhd.enable = false;
  yabai.enable = false;
  sketchybar.enable = false;

  services.nix-daemon.enable = true;
  # Set Git commit hash for darwin-version.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      sketchybar-app-font
      (nerdfonts.override {
        fonts = [
          "FiraCode"
        ];
      })
    ];
  };

  # Networking
  networking = {
    knownNetworkServices = [ "Wi-Fi" ];
    dns = [ "1.1.1.1" "8.8.8.8" ];
    computerName = "appl-mbp16";
    hostName = "appl-mbp16";
  };

  # add PAM
  security.pam.enableSudoTouchIdAuth = true;

  # System preferences
  system = {
    stateVersion = 4;
    activationScripts.extraUserActivation.text = ''sudo chsh -s ${pkgs.zsh}/bin/zsh'';
    # default settings within System Preferences
    defaults = {
      NSGlobalDomain = {
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };
      dock = {
        autohide = true;
        largesize = 48;
        tilesize = 24;
        magnification = true;
        mineffect = "genie";
        orientation = "bottom";
        showhidden = false;
        show-recents = false;
      };
      finder = {
        AppleShowAllFiles = true;
        QuitMenuItem = false;
      };
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
      };
    };
  };

  programs.zsh = {
    enable = true;
    promptInit = ''source ${pkgs.gitstatus}/share/gitstatus/gitstatus.prompt.zsh'';
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    loadInNixShell = true;
  };
  programs.nix-index.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
  };
}
