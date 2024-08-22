{
  pkgs,
  lib,
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
  gpg.enable = true;

  nix-homebrew = {
    inherit user;
    enable = true;
    enableRosetta = true;
    autoMigrate = true;
    extraEnv = {
      HOMEBREW_NO_ANALYTICS = "1";
    };
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    onActivation.extraFlags = ["--verbose"];
    taps = [
      "homebrew/homebrew-bundle"
      "apple/apple"
    ];
    casks = [
      "arc"
      "google-chrome"
      "firefox"
      "zotero"
      "discord"
      "zoom"
      "obs"
      "gather"
      "obsidian"
      "rectangle"
      "steam"
      "zed"
      "zed@preview"
      "orbstack"
      # TODO: for sequoia
      # "raycast"
      # "karabiner-elements"
    ];
    # nix run nixpkgs#mas -- search <apps>
    masApps = {
      Bitwarden = 1352778147;
      TestFlight = 899247664;
      Messenger = 1480068668;
      DaisyDisk = 411643860;
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

  environment = {
    shells = [pkgs.zsh];
    systemPath = ["/opt/homebrew/bin" "/opt/homebrew/sbin"];
  };

  nix.settings = {
    log-lines = 20;
    keep-going = false;
    auto-optimise-store = true;
    trusted-users = [user];
    sandbox = false;
    max-jobs = "auto";
  };

  nix.gc = {
    inherit user;
    automatic = true;
    interval.Hour = 6;
    options = ''
      --delete-older-than 3d --max-freed $((128 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | ${lib.getExe' pkgs.gawk "awk"} '{ print $4 }')))
    '';
  };

  nix.optimise = {
    inherit user;
    automatic = true;
    interval.Hour = 6;
  };

  # Set Git commit hash for darwin-version.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  fonts.packages = with pkgs; [
    (nerdfonts.override {
      fonts = [
        "FiraCode"
      ];
    })
  ];

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
