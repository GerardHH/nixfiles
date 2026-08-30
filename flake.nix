{
  description = "Personal dotfiles, managed with Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      mkHome =
        {
          username,
          modules,
        }:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit username;
            dotfilesDir = "/home/${username}/nixfiles";
          };
          modules = [ ./home/common.nix ] ++ modules;
        };
    in
    {
      homeConfigurations = {
        container = mkHome {
          username = "ubuntu";
          modules = [ ./home/container.nix ];
        };

        host = mkHome {
          username = "gerard";
          modules = [ ./home/host.nix ];
        };
      };
    };
}
