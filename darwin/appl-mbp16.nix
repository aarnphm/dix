{
  pkgs,
  user,
  inputs,
  ...
}: rec {
  imports = [
    ./modules
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  programs.zsh = {
    enable = true;
    promptInit = ''source ${pkgs.gitstatus}/share/gitstatus/gitstatus.prompt.zsh'';
    shellInit = ''
      zmodload zsh/mapfile
      bwpassfile="${users.users.${user}.home}/bw.pass"
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
  gpg.enable = true;

  nix-homebrew = {
    inherit user;
    enable = true;
    enableRosetta = true;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
    };
    mutableTaps = false;
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    casks = [
      "arc"
      "google-chrome"
      "firefox"

      "zotero"
      "discord"
      "zoom"
      "obs"

      "gather"
      "notion"
      "obsidian"
      "rectangle"

      "steam"
      "zed"

      # TODO: for sequoia
      # "raycast"
      # "karabiner-elements"
    ];
    # nix run nixpkgs#mas -- search <apps>
    masApps = {
      Bitwarden = 1352778147;
      TestFlight = 899247664;
      Messenger = 1480068668;
      "Slack for Desktop" = 803453959;
      "NordVPN - VPN for privacy" = 905953485;
      "WhatsApp Messenger" = 310633997;
    };
  };

  # Users
  users.users.${user} = {
    shell = pkgs.zsh;
    home = "/Users/${user}";
    createHome = true;
  };

  environment.shells = [pkgs.zsh];
  environment.darwinConfig = "${users.users.${user}.home}/workspace/dix";
  environment.systemPath = ["/opt/homebrew/bin" "/opt/homebrew/sbin"];

  nix.settings = {
    log-lines = 20;
    keep-going = true;
    auto-optimise-store = true;
    trusted-users = ["root" user];
    sandbox = false; # TODO: investigate how to do actual pure building in darwin
    max-jobs = "auto";
  };
  nix.nixPath = [{darwin = "${users.users.${user}.home}/workspace/dix";}];

  nix.gc = {
    automatic = true;
    interval.Hour = 6;
    options = "--delete-older-than 3d --max-freed $((25 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";
  };

  nix.optimise = {
    automatic = true;
    interval.Hour = 6;
  };

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
    dns = ["1.1.1.1" "8.8.8.8"];
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
}
