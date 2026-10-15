.PHONY: test
test:
	@echo "Running tests with plenary.nvim..."
	@nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  test   - Run tests with plenary.nvim"
	@echo "  lint   - Check formatting (StyLua) and diagnostics (lua-language-server)"
	@echo "  format - Format Lua files with StyLua"
	@echo "  help   - Show this help message"

.PHONY: lint
lint:
	@echo "Checking format with StyLua..."
	@stylua --check lua plugin tests
	@echo "Running lua-language-server diagnostics..."
	@VIMRUNTIME="$$(nvim --clean --headless -c 'lua io.write(vim.env.VIMRUNTIME)' -c q 2>&1)" \
		lua-language-server --check . --checklevel=Information

.PHONY: format
format:
	@stylua lua plugin tests
