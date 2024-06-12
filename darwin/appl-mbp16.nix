{ pkgs, lib, user, inputs, ... }:
let
  homePath = "/Users/${user}";
in
{
  imports = [
    ./modules
    (import ../dix { inherit pkgs lib; }).darwinModules
    inputs.nix.darwinModules.default
  ];

  # Users
  users.users.${user} = {
    shell = pkgs.zsh;
    home = homePath;
    createHome = true;
  };

  environment.shells = [ pkgs.zsh ];
  environment.darwinConfig = "${homePath}/workspace/dix";

  # TODO: turn this back on once upgrade-nix-store-path-url is stable
  nix.checkConfig = true;
  nix.settings = {
    log-lines = 20;
    keep-going = true;
    auto-optimise-store = true;
    trusted-users = [ "root" user ];
    sandbox = false; # TODO: investigate how to do actual pure building in darwin
    max-jobs = "auto";
  };
  nix.nixPath = [
    { darwin = "${homePath}/workspace/dix"; }
    "/nix/var/nix/profiles/per-user/root/channels"
  ];

  nix.gc = {
    automatic = true;
    interval.Hour = 6;
    options = "--delete-older-than 3d --max-freed $((25 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";
  };

  nix.optimise = {
    automatic = true;
    interval.Hour = 6;
  };

  skhd.enable = false;
  yabai.enable = false;
  sketchybar.enable = false;

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
    knownNetworkServices = [
      "Wi-Fi"
      "Thunderbolt Ethernet Slot 2"
    ];
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
    shellInit = ''
      zmodload zsh/mapfile
      bwpassfile="${homePath}/bw.pass"
      if [[ -f "$bwpassfile" ]]; then
        bitwarden=("''${(f@)mapfile[$bwpassfile]}")
        export BW_MASTER=$bitwarden[1]
        export BW_CLIENTID=$bitwarden[2]
        export BW_CLIENTSECRET=$bitwarden[3]
      fi

    '';
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
