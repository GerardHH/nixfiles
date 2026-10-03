{
    description = "Personal dotfiles, managed with Home Manager";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
        nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
        home-manager = {
            url = "github:nix-community/home-manager/release-26.05";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        fzf-tab-completion = {
            url = "github:lincheney/fzf-tab-completion";
            flake = false;
        };
        nixgl = {
            url = "github:nix-community/nixGL";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        sops-nix = {
            url = "github:Mic92/sops-nix";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs =
        {
            nixpkgs,
            nixpkgs-unstable,
            home-manager,
            fzf-tab-completion,
            nixgl,
            sops-nix,
            ...
        }:
        let
            system = "x86_64-linux";

            unstable = import nixpkgs-unstable {
                inherit system;
                # Only allow specific proprietary packages
                config.allowUnfreePredicate =
                    pkg:
                    builtins.elem (nixpkgs-unstable.lib.getName pkg) [
                        "claude-code"
                    ];
            };

            pkgs = import nixpkgs {
                inherit system;
                overlays = [
                    nixgl.overlays.default
                    (_final: _prev: { inherit (unstable) claude-code; })
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
                        inherit username fzf-tab-completion sops-nix;
                        dotfilesDir = "/home/${username}/nixfiles";
                    };
                    modules = [ ./home/common.nix ] ++ modules;
                };
        in
        {
            homeConfigurations = {
                container = mkHome {
                    username = "ubuntu";
                    modules = [ ./home/profiles/container ];
                };

                lely = mkHome {
                    username = "gerard";
                    modules = [ ./home/profiles/lely ];
                };

                personal = mkHome {
                    username = "gerard";
                    modules = [ ./home/profiles/personal ];
                };
            };
        };
}
