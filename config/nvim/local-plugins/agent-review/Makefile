# Specs for agent-review, run by plenary.nvim's busted in headless nvim, laid
# out like neotest-testmate's. tests/unit drives the plugin through
# `collect` on scratch git repositories it makes per test (tests/helpers.lua),
# so they test what the front ends get: entries, notes and stale marks.
#
#   make test                                     # clones plenary.nvim first
#   make test DEPS=$HOME/.local/share/nvim/lazy   # or uses lazy.nvim's
#
# Everything runs in a sandbox of XDG directories, so neither your own nvim
# config nor its state and logs take part. git runs without your global and
# system config (GIT_CONFIG_GLOBAL, GIT_CONFIG_NOSYSTEM): hooks, commit
# signing or an excludesfile there would change what the specs see.

.PHONY: test unit deps clean

SANDBOX ?= .sandbox
# Plugin checkouts the specs load, one directory each: plenary.nvim only.
DEPS ?= $(SANDBOX)/deps

export XDG_CACHE_HOME = $(abspath $(SANDBOX))/cache
export XDG_CONFIG_HOME = $(abspath $(SANDBOX))/config
export XDG_DATA_HOME = $(abspath $(SANDBOX))/data
export XDG_STATE_HOME = $(abspath $(SANDBOX))/state
export AGENT_REVIEW_DEPS = $(abspath $(DEPS))
export GIT_CONFIG_GLOBAL = /dev/null
export GIT_CONFIG_NOSYSTEM = 1

# sequential: one spec file at a time; timeout: per spec file, in ms.
BUSTED = nvim --headless --noplugin -u tests/minimal_init.lua -c \
    "PlenaryBustedDirectory $(1) {minimal_init = 'tests/minimal_init.lua', sequential = true, timeout = 60000}"

test: deps unit

unit:
	@mkdir --parents $(XDG_STATE_HOME)
	$(call BUSTED,tests/unit)

# A shallow clone of plenary.nvim; skipped when DEPS already has it.
deps:
	@test -d "$(DEPS)/plenary.nvim" || git clone --depth 1 --filter blob:none https://github.com/nvim-lua/plenary.nvim "$(DEPS)/plenary.nvim"

clean:
	rm --recursive --force $(SANDBOX)
