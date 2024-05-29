{ pkgs, inputs, ... }: {
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

  environment.shells = with pkgs; [ zsh ];

  nix.settings = {
    auto-optimise-store = true;
    experimental-features = "nix-command flakes";
    trusted-users = [ "root" "aarnphm" ];
    trusted-substituters = [ "https://nix-community.cachix.org" ];
    trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
  };

  nix.gc = {
    automatic = true;
    interval.Hour = 3;
    options = "--delete-older-than 7d --max-freed $((25 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";
  };

  # Set Git commit hash for darwin-version.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  programs.nix-index.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
