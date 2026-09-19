{
  config,
  ...
}:
{
  # Makes Nix-installed GUI apps show up in the GNOME launcher.
  #
  # Their .desktop files and icons live in ~/.nix-profile/share, and their
  # Exec= lines are bare command names resolved against PATH. gnome-shell runs
  # under the systemd user manager, which builds its environment from
  # ~/.config/environment.d and never sources hm-session-vars.sh — so without
  # this file the profile is invisible to it: no entries, no icons, and any
  # entry that did get found would fail to launch.
  #
  # Only read when the session is constructed: log out and in to apply.
  xdg.configFile."environment.d/10-nix-profile.conf".text = ''
    PATH=${config.home.profileDirectory}/bin:''${PATH}
    #TODO remove snap path when snapp-less
    XDG_DATA_DIRS=${config.home.profileDirectory}/share:''${XDG_DATA_DIRS}:/usr/local/share:/usr/share:/var/lib/snapd/desktop
  '';
}
