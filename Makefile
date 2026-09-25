.PHONY: test
test:
	@echo "Running tests with plenary.nvim..."
	@nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  test  - Run tests with plenary.nvim"
	@echo "  help  - Show this help message"
