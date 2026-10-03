{
    config,
    pkgs,
    ...
}:
{
    imports = [
        ../../modules/base.nix
    ];

    # TERM arrives from the host shell: "alacritty", or "tmux-256color" inside
    # tmux. The image carries only Ubuntu's ncurses-base terminfo, which has
    # neither. Pull it in through the profile so that the image remains untouched.
    home.packages = [ pkgs.ncurses ];
    home.sessionVariables.TERMINFO = "${config.home.profileDirectory}/share/terminfo";

    # Force TERM to be set so that nvim and friends can properly populate the terminal.
    home.sessionVariables.TERM = "xterm-256color";

    # The image ships toolchains that have to match the project it was built for:
    # clangd's builtin headers and target must agree with the compiler behind
    # compile_commands.json, and rust-analyzer with the rustup toolchain. Editor
    # support stays on; only the binaries come from the image. Nix keeps providing
    # its own PATH entry first, so leaving these true would shadow the image's.
    languages.c_cpp.provideTools = false;
    languages.python.provideTools = false;
    languages.rust.provideTools = false;
}
