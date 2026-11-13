{ ... }:
{
    imports = [
        ../../modules/alacritty.nix
        ../../modules/base.nix
        ../../modules/claude.nix
        ../../modules/clipboard.nix
        ../../modules/devcontainer.nix
        ../../modules/gnome-keys.nix
        ../../modules/graphical-session.nix
        ../../modules/zsa.nix
        ./secrets.nix
        ./ssh.nix
    ];
}
