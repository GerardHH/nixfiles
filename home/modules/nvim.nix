{
  pkgs,
  link,
  ...
}:
{
  imports = [
    ./fzf.nix
  ];

  home.packages = with pkgs; [
    neovim

    fd # fzf-lua file provider
    ripgrep # fzf-lua grep provider
  ];

  xdg.configFile."nvim".source = link "config/nvim";
}
