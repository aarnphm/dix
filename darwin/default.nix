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
  programs.nix-index = {
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
  ids.uids.nixbld = 400;

  environment = {
    shells = [pkgs.zsh];
    systemPath = ["/opt/homebrew/bin" "/opt/homebrew/sbin"];
  };

  power = {
    sleep.display = 30;
  };

  nix.nrBuildUsers = 32;

  nix.settings = {
    log-lines = 128;
    keep-going = true;
    keep-derivations = true;
    keep-outputs = true;
    trusted-users = [user];
    sandbox = true;
    extra-sandbox-paths = ["/private/tmp" "/private/var/tmp" "/usr/bin/env"];
    max-jobs = "auto";
    always-allow-substitutes = true;
    bash-prompt-prefix = "(nix:$name)\\040";
    experimental-features = ["nix-command" "flakes"];
    extra-nix-path = ["nixpkgs=flake:nixpkgs"];
    upgrade-nix-store-path-url = "https://install.determinate.systems/nix-upgrade/stable/universal";
  };

  nix.gc = {
    automatic = true;
    interval.Hour = 6;
    options = ''
      --delete-older-than 3d --max-freed $((128 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | ${lib.getExe' pkgs.gawk "awk"} '{ print $4 }')))
    '';
  };

  nix.optimise = {
    automatic = true;
    interval.Hour = 6;
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
        autohide = true;
        largesize = 48;
        tilesize = 24;
        magnification = true;
        mineffect = "genie";
        orientation = "bottom";
        showhidden = true;
        show-recents = true;
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
