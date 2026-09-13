{
  pkgs,
  link,
  ...
}:
{
  imports = [
    ./fzf.nix
    ./ripgrep.nix
  ];

  home.packages = with pkgs; [
    neovim

    fd # fzf-lua file provider
  ];

  xdg.configFile."nvim".source = link "config/nvim";
}
