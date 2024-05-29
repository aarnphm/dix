{ pkgs, ... }: {
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

  # System preferences
  system = {
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
