# Specs for neotest-testmate, run by plenary.nvim's busted in headless nvim,
# laid out like neotest-ctest's: tests/unit calls the adapter's functions
# directly, tests/integration runs it through neotest itself. tests/container
# needs the colcon test bed built where the specs run, so it is left out of
# `make test`: see the container target.
#
# Everything runs in a sandbox of XDG directories, so neither your own nvim
# config nor its state and logs take part (neotest.log ends up in
# $(SANDBOX)/state/nvim/). Locally, point DEPS at your lazy.nvim plugins and
# FIXTURES at built test projects, e.g. from nixfiles:
#
#   make test DEPS=$HOME/.local/share/nvim/lazy \
#       FIXTURES=$HOME/nixfiles/dev-container-tests
#
# PLUGIN picks the adapter under test, e.g. an older commit's tree, to tell a
# regression from a problem in the specs.

.PHONY: test unit integration container deps clean

SANDBOX ?= .sandbox
# Plugin checkouts the specs load: plenary.nvim, nvim-nio, neotest and
# neotest-ctest (for its Catch2 query), one directory each.
DEPS ?= $(SANDBOX)/deps
# Built C++ projects the specs run, see tests/helpers.lua.
FIXTURES ?= tests/fixtures
PLUGIN ?= .
# A directory with parser/cpp.so; Home Manager's nvim runtime has one.
PARSERS ?= $(NVIM_NIX_RUNTIME)

export XDG_CACHE_HOME = $(abspath $(SANDBOX))/cache
export XDG_CONFIG_HOME = $(abspath $(SANDBOX))/config
export XDG_DATA_HOME = $(abspath $(SANDBOX))/data
export XDG_STATE_HOME = $(abspath $(SANDBOX))/state
export TESTMATE_DEPS = $(abspath $(DEPS))
export TESTMATE_FIXTURES = $(abspath $(FIXTURES))
export TESTMATE_PLUGIN = $(abspath $(PLUGIN))
export TESTMATE_PARSERS = $(PARSERS)
# Per async test (nio.tests.it); its default of 2 s is too short for a test
# executable to run. The integration specs give up earlier, with a message
# saying how far neotest got.
export PLENARY_TEST_TIMEOUT ?= 60000

# sequential: one spec file at a time, so the integration run has the
# machine to itself; timeout: per spec file, in ms.
BUSTED = nvim --headless --noplugin -u tests/minimal_init.lua -c \
    "PlenaryBustedDirectory $(1) {minimal_init = 'tests/minimal_init.lua', sequential = true, timeout = 180000}"

test: unit integration

unit:
	@mkdir --parents $(XDG_STATE_HOME)
	$(call BUSTED,tests/unit)

integration:
	@mkdir --parents $(XDG_STATE_HOME)
	$(call BUSTED,tests/integration)

# A suite run of the colcon test bed. The adapter finds an executable by the
# source paths in it, so run this in the test bed's container after a
# `colcon build`, with FIXTURES at the path the build saw: the devcontainer
# CLI mounts the whole nixfiles repo under /workspaces, not the test bed alone.
#
#   make container DEPS=$HOME/.local/share/nvim/lazy \
#       FIXTURES=/workspaces/nixfiles/dev-container-tests
container:
	@mkdir --parents $(XDG_STATE_HOME)
	$(call BUSTED,tests/container)

# Shallow clones of the dependencies, for CI; skipped when DEPS already has them.
deps:
	@for repo in nvim-lua/plenary.nvim nvim-neotest/nvim-nio nvim-neotest/neotest orjangj/neotest-ctest; do \
	    dir="$(DEPS)/$${repo#*/}"; \
	    test -d "$$dir" || git clone --depth 1 --filter blob:none "https://github.com/$$repo" "$$dir"; \
	done

clean:
	rm --recursive --force $(SANDBOX)
