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

  # add PAM
  security.pam.enableSudoTouchIdAuth = true;

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

  # packages
  environment.systemPackages = with pkgs; [
    # nix
    cachix

    # editor
    vim
    neovim-developer
    alacritty

    # kubernetes
    kubernetes-helm
    k9s
    buildkit
    qemu
    pplatex
    eksctl
    colima
    lima
    krew
    k9s
    lazydocker
    kind
    skopeo
    earthly

    # git
    git
    gitui
    lazygit
    git-lfs
    delta

    # languages
    # TODO: setup openjdk
    go
    sass
    protobuf
    nodejs_20
    rustup
    pyenv
    xz
    # tools for language, lsp, linter, etc.
    tree-sitter
    eclint
    nixfmt-rfc-style
    nixpkgs-fmt
    grpcurl
    taplo
    stylua
    selene
    buf
    protolint
    sqlite
    postgresql_14
    llvm_17
    openblas
    enchant

    # terminal
    any-nix-shell
    zsh-powerlevel10k
    zsh-completions
    zsh-f-sy-h
    zsh-history-substring-search

    direnv
    tmux
    jq
    yq
    gh
    tree
    btop
    zip
    pstree
    eza # exa-maintained fork
    zoxide
    rm-improved
    fd
    fzf
    bat
    ripgrep
    tmux
    asciinema
    watch
    ffmpeg
    cmake
    dtach
    zstd
    gnused
    gnupg
    hyperfine
  ];
}
