{
    pkgs,
    link,
    ...
}:
{
    imports = [
        ./fonts.nix
        ./git.nix
        ./languages
        ./nvim.nix
        ./shell.nix
    ];

    home.packages = with pkgs; [
        btop
    ];

    xdg.configFile = {
        "btop".source = link "config/btop";
    };
}
