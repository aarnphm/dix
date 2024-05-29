{ inputs, nixpkgs, system, nix-darwin, home-manager, ... }:
let
  user = "aarnphm";
in
{
  appl-mbp16 = nix-darwin.lib.darwinSystem {
    inherit system;
    specialArgs = { inherit inputs system user; pkgs = nixpkgs; };
    modules = [
      ./appl-mbp16.nix
      home-manager.darwinModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users."${user}" = import ./home.nix;
      }
    ];
  };
}
