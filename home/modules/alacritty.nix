{
  pkgs,
  link,
  ...
}:
{
  programs.alacritty = {
    enable = true;

    # Host's EGL/Mesa is not the stack Nix builds against, so the plain
    # package cannot create a display. nixGL points libglvnd at nixpkgs' Mesa.
    # symlinkJoin rather than a bare wrapper script, so share/applications,
    # share/icons and the terminfo entry come along.
    package = pkgs.symlinkJoin {
      name = "alacritty-nixgl";
      paths = [ pkgs.alacritty ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        rm $out/bin/alacritty
        makeWrapper ${pkgs.nixgl.nixGLIntel}/bin/nixGLIntel $out/bin/alacritty \
          --add-flags ${pkgs.alacritty}/bin/alacritty
      '';
      inherit (pkgs.alacritty) version meta;
    };

    # `settings` left empty on purpose: the module only writes alacritty.toml
    # when settings != {}, so the symlink below stays the source of truth.
  };

  xdg.configFile."alacritty".source = link "config/alacritty";
}
