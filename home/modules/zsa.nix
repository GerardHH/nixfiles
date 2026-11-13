{ pkgs, ... }:
{
    # Keymapp: ZSA's app for flashing the Voyager and viewing its layout.
    # Unfree, so flake.nix allows it by name. It reaches the keyboard only
    # through the udev rules in host/udev/50-zsa.rules, which Home Manager
    # cannot install: `host-setup.sh apply` does, and preflight warns when
    # they are missing.
    home.packages = [
        (pkgs.symlinkJoin {
            name = "keymapp-nixgl";
            paths = [ pkgs.keymapp ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
                rm $out/bin/keymapp
                makeWrapper ${pkgs.nixgl.nixGLIntel}/bin/nixGLIntel $out/bin/keymapp \
                  --add-flags ${pkgs.keymapp}/bin/keymapp
            '';
        })
    ];

    dconf.settings."org/gnome/desktop/peripherals/touchpad" = {
        tap-to-click = true;
        tap-and-drag = true;
        tap-and-drag-lock = true;
    };
}
