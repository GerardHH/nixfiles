# nixfiles

## Key layers

Each modifier belongs to one layer, so a key never means two things:

| Modifier | Layer                                                         | Examples                                        |
| -------- | ------------------------------------------------------------- | ----------------------------------------------- |
| Ctrl     | The program in focus: nvim, bash, fzf, lazygit, Claude Code   | `C-h/j/k/l` nvim windows, `C-r` history search  |
| Alt      | Programs that control other programs: tmux                    | `M-h/j/k/l` tmux panes, `M-Space` tmux menu     |
| Super    | The window manager (none yet)                                 |                                                 |

- Bindings set in this repo follow the table. When a program needs a variant
  of a Ctrl key, it uses Ctrl-Shift, never Alt (e.g. mini.move on
  `C-S-h/j/k/l`).
- Built-in Alt defaults of programs and GNOME (readline's `M-b`, `M-f`, `M-.`,
  fzf, Claude Code, GNOME's Alt-Tab) stay until tmux claims that key. Then
  tmux wins: GNOME's are unbound in `home/modules/gnome-keys.nix`.
- Exception: Alacritty's built-in Ctrl-Shift-C/V (copy/paste) and
  Ctrl-=/-/0 (font size).
- Ctrl-Shift-letter only reaches a program through the CSI-u codes in
  `config/alacritty/alacritty.toml`. Other terminals send plain Ctrl-letter.
