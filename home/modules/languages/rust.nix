{ pkgs, ... }:
{
  languages.rust = {
    # rustaceanvim drives this; the toolchain itself (cargo, rustc) is expected
    # to come from the project, via rustup or a devshell.
    packages = [ pkgs.rust-analyzer ];
    # rustaceanvim starts rust-analyzer itself, so there is no vim.lsp.config
    # entry and nothing for nvim-lspconfig to load on.
    servers = [ ];
    filetypes = [ ];
  };
}
