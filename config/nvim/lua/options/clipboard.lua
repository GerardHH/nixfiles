local opt = vim.opt

opt.clipboard:append("unnamedplus")

-- Neovim looks for wl-copy/xclip/xsel on PATH. In a devcontainer or over SSH
-- they are missing, or would talk to the wrong display. Fall back to OSC 52 so
-- the terminal emulator holding the real clipboard does the copying.
local has_helper = vim.fn.executable("wl-copy") == 1
	or vim.fn.executable("xclip") == 1
	or vim.fn.executable("xsel") == 1

if vim.env.SSH_TTY or not has_helper then
	local osc52 = require("vim.ui.clipboard.osc52")
	-- OSC 52 *reads* are refused by nearly every terminal (Alacritty included)
	-- since they let any program exfiltrate the clipboard. Serve pastes from
	-- the unnamed register instead of issuing a query that will hang.
	local function paste() return { vim.split(vim.fn.getreg("0"), "\n"), vim.fn.getregtype("0") } end
	vim.g.clipboard = {
		name = "OSC 52",
		copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
		paste = { ["+"] = paste, ["*"] = paste },
	}
end
