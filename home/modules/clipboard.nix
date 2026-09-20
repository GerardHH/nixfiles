{
  pkgs,
  ...
}:
{
  # Neovim has no clipboard of its own: it shells out to a helper, picking
  # wl-copy or xclip at runtime depending on whether $WAYLAND_DISPLAY is set.
  # Install both so the right one exists whichever way the GNOME session came up.
  home.packages = with pkgs; [
    wl-clipboard # wl-copy / wl-paste
    xclip # X11 and XWayland
  ];
}
