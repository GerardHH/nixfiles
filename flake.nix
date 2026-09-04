{
  description = "Personal dotfiles, managed with Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fzf-tab-completion = {
      url = "github:lincheney/fzf-tab-completion";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      fzf-tab-completion,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        # Only allow specific proprietary packages
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "claude-code"
          ];
      };

      mkHome =
        {
          username,
          modules,
        }:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit username fzf-tab-completion;
            dotfilesDir = "/home/${username}/nixfiles";
          };
          modules = [
            ./home/common.nix
            ./home/shell.nix
            ./home/tools.nix
            ./home/nvim.nix
            ./home/languages/bash.nix
            ./home/languages/lua.nix
            ./home/languages/markdown.nix
            ./home/languages/nix.nix
          ]
          ++ modules;
        };
    in
    {
      homeConfigurations = {
        container = mkHome {
          username = "ubuntu";
          modules = [
            ./home/container.nix
          ];
        };

        host = mkHome {
          username = "gerard";
          modules = [
            ./home/host.nix
          ];
        };
      };
    };
}
