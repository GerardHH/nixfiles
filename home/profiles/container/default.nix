{ ... }:
{
  imports = [
    ../../modules/base.nix
  ];

  # Let Home Manager own the shell here: it writes ~/.bashrc and sources
  # hm-session-vars.sh, so home.packages land on PATH for `devcontainer exec`.
  programs.bash.enable = true;

  # The image ships toolchains that have to match the project it was built for:
  # clangd's builtin headers and target must agree with the compiler behind
  # compile_commands.json, and rust-analyzer with the rustup toolchain. Editor
  # support stays on; only the binaries come from the image. Nix keeps providing
  # its own PATH entry first, so leaving these true would shadow the image's.
  languages.c_cpp.provideTools = false;
  languages.python.provideTools = false;
  languages.rust.provideTools = false;
}
