{ ... }:
{
    # Key layers (see README.md): Take or move gnome keybindings
    dconf.settings."org/gnome/desktop/wm/keybindings" = {
        # Alt+Space opens the window menu, reserve it for tmux
        activate-window-menu = [ ];
    };
}
