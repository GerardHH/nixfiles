# Specs for neotest-testmate, run by plenary.nvim's busted in headless nvim,
# laid out like neotest-ctest's: tests/unit calls the adapter's functions
# directly, tests/integration runs it through neotest itself, and tests/suite
# runs every test file of the colcon fixture through neotest, as <leader>tp
# does.
#
# The specs run the projects in tests/fixtures, and the adapter finds an
# executable by the source paths in it: so the fixtures are built where the
# specs run, from the same paths. That is the container in .devcontainer/,
# which has the tools every fixture builds with. From nixfiles on the host,
# one command builds and runs everything in it:
#
#   bin/nix-devcontainer.sh config/nvim/local-plugins/neotest-testmate -- make check
#
# In the container's shell, `make check` does the same, and `make test` runs
# the specs again without building. A pipeline runs `make check`.
#
# Everything runs in a sandbox of XDG directories, so neither your own nvim
# config nor its state and logs take part (neotest.log ends up in
# $(SANDBOX)/state/nvim/). `make deps` clones the plugins the specs load into
# DEPS, unless they are there already, e.g. with your lazy.nvim's:
#
#   make check DEPS=$HOME/.local/share/nvim/lazy
#
# PLUGIN picks the adapter under test, e.g. an older commit's tree, to tell a
# regression from a problem in the specs.

.PHONY: check fixtures test unit integration suite deps clean clean-fixtures

SANDBOX ?= .sandbox
# Plugin checkouts the specs load: plenary.nvim, nvim-nio, neotest,
# neotest-ctest (for its Catch2 query) and nvim-dap (for the debug spec), one
# directory each.
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

# Everything a pipeline needs, in order: make runs prerequisites left to right
# (unless run with --jobs).
check: deps fixtures test

# Builds every fixture in place; each build tool skips what is up to date.
# colcon is in the container only; without it, say where to run this.
fixtures:
	@command -v colcon >/dev/null || { echo "colcon not found: run 'make fixtures' in the container, see .devcontainer/" >&2; exit 1; }
	cd $(FIXTURES)/cmake-catch2 && cmake --preset debug && cmake --build --preset debug
	cd $(FIXTURES)/colcon && colcon build

test: unit integration suite

unit:
	@mkdir --parents $(XDG_STATE_HOME)
	$(call BUSTED,tests/unit)

integration:
	@mkdir --parents $(XDG_STATE_HOME)
	$(call BUSTED,tests/integration)

suite:
	@mkdir --parents $(XDG_STATE_HOME)
	$(call BUSTED,tests/suite)

# Shallow clones of the dependencies; skipped when DEPS already has them.
deps:
	@for repo in nvim-lua/plenary.nvim nvim-neotest/nvim-nio nvim-neotest/neotest orjangj/neotest-ctest mfussenegger/nvim-dap; do \
	    dir="$(DEPS)/$${repo#*/}"; \
	    test -d "$$dir" || git clone --depth 1 --filter blob:none "https://github.com/$$repo" "$$dir"; \
	done

clean:
	rm --recursive --force $(SANDBOX)

# The fixtures' build output. Needed after the fixtures moved, or were built
# at other paths: CMake refuses a build directory made for another source path.
clean-fixtures:
	rm --recursive --force $(FIXTURES)/cmake-catch2/build $(FIXTURES)/cmake-catch2/.cache
	rm --recursive --force $(FIXTURES)/colcon/build $(FIXTURES)/colcon/install $(FIXTURES)/colcon/log $(FIXTURES)/colcon/.cache
