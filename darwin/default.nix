{
  pkgs,
  lib,
  user,
  inputs,
  computerName,
  ...
}: {
  imports = [
    ./modules
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  programs.zsh = {
    enable = true;
  };
  gpg.enable = true;

  nix-homebrew = {
    inherit user;
    enable = true;
    enableRosetta = pkgs.isArm;
    autoMigrate = true;
    extraEnv = {
      HOMEBREW_NO_ANALYTICS = "1";
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      extraFlags = ["--verbose"];
      autoUpdate = true;
    };
    brews = [
      "ast-grep"
      "gnu-tar"
      "pngpaste"
      "asciidoctor"
      "plantuml"
    ];
    casks = [
      "arc"
      "google-chrome"
      "zotero"
      "discord"
      "zoom"
      "obs"
      "ollama"
      "gather"
      "obsidian"
      "rectangle"
      "steam"
      "orbstack"
      "alt-tab"
      "raycast"
      "karabiner-elements"
      "zed@preview"
      "middleclick"
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

  power = {
    sleep.display = 30;
  };

  nix = {
    enable = false;
    settings = {
      log-lines = 20;
      keep-going = false;
      sandbox = false;
      trusted-users = [user];
      max-jobs = "auto";
      always-allow-substitutes = true;
      bash-prompt-prefix = "(nix:$name)\\040";
      experimental-features = ["nix-command" "flakes"];
      extra-nix-path = ["nixpkgs=flake:nixpkgs"];
      upgrade-nix-store-path-url = "https://install.determinate.systems/nix-upgrade/stable/universal";
    };

    gc = {
      automatic = false; # NOTE: need nix.enable
      interval.Hour = 6;
      options = ''
        --delete-older-than 3d --max-freed $((128 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | ${lib.getExe' pkgs.gawk "awk"} '{ print $4 }')))
      '';
    };

    optimise = {
      automatic = false; # NOTE: need nix.enable
      interval.Hour = 6;
    };
  };

  # Networking
  networking = {
    inherit computerName;
    dns = ["1.1.1.1" "8.8.8.8"];
    knownNetworkServices = [
      "Wi-Fi"
      "Thunderbolt Ethernet Slot 2"
    ];
    hostName = computerName;
  };

  # add PAM
  security = {
    pam.services.sudo_local = {
      touchIdAuth = true;
      watchIdAuth = true;
    };
  };

  # System preferences
  system = {
    stateVersion = 6;
    # Set Git commit hash for darwin-version.
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
    primaryUser = user;

    keyboard = {
      enableKeyMapping = true;
    };

    # default settings within System Preferences
    defaults = {
      NSGlobalDomain = {
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticInlinePredictionEnabled = true;
      };
      dock = {
        autohide = false;
        magnification = true;
        mineffect = "scale";
        orientation = "bottom";
        showhidden = true;
        show-recents = false;
        mru-spaces = true;
      };
      finder = {
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        QuitMenuItem = true;
        FXEnableExtensionChangeWarning = false;
      };
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = true;
      };
    };
  };
}
