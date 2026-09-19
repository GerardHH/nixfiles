{
  pkgs,
  link,
  ...
}:
{
  imports = [
    ./fonts.nix
    ./languages/bash.nix
    ./languages/lua.nix
    ./languages/markdown.nix
    ./languages/nix.nix
    ./languages/node.nix
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
