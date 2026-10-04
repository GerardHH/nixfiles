{ config, lib, ... }:
let
    inherit (lib)
        attrValues
        concatMap
        filterAttrs
        mkEnableOption
        mkOption
        types
        ;

    enabled = filterAttrs (_: language: language.enable) config.languages;
    provided = filterAttrs (_: language: language.provideTools) enabled;
in
{
    imports = [
        ./bash.nix
        ./c_cpp.nix
        ./docker.nix
        ./editorconfig.nix
        ./git.nix
        ./json.nix
        ./lua.nix
        ./markdown.nix
        ./nix.nix
        ./node.nix
        ./python.nix
        ./rust.nix
        ./toml.nix
        ./xml.nix
        ./yaml.nix
    ];

    options.languages = mkOption {
        default = { };
        description = ''
            Language support this profile wants. `enable` covers the editor side
            (treesitter grammars, filetypes, servers to activate) and is on by
            default everywhere; it is cheap. `provideTools` decides who puts the
            binaries on disk: Nix, or the surrounding environment.
        '';
        type = types.attrsOf (
            types.submodule (
                { name, ... }:
                {
                    options = {
                        enable = mkEnableOption "editor support for ${name}" // {
                            default = true;
                        };

                        provideTools = mkOption {
                            type = types.bool;
                            default = true;
                            description = ''
                                Install `packages` through Nix. False where the environment
                                ships a toolchain that has to match the project, such as
                                clangd in a dev container image.
                            '';
                        };

                        packages = mkOption {
                            type = types.listOf types.package;
                            default = [ ];
                            description = "Language servers, formatters and linters for ${name}.";
                        };

                        grammars = mkOption {
                            type = types.listOf types.str;
                            default = [ name ];
                            description = "nvim-treesitter grammar names this language needs. Default: name of the language";
                        };

                        servers = mkOption {
                            type = types.listOf types.str;
                            default = [ ];
                            description = "vim.lsp.config names to enable for this language.";
                        };

                        formatters = mkOption {
                            type = types.listOf types.str;
                            default = [ ];
                            description = ''
                                LSP clients whose formatting runs on save for ${name}: names
                                from `servers`, or "null-ls" for a formatter that runs through
                                none-ls. One per file type, so two formatters never take turns
                                on the same file.
                            '';
                        };

                        filetypes = mkOption {
                            type = types.listOf types.str;
                            default = [ name ];
                            description = "Filetypes that should trigger loading the LSP plugins. Default: name of the language";
                        };
                    };
                }
            )
        );
    };

    config.home.packages = concatMap (language: language.packages) (attrValues provided);
}
