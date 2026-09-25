-- Minimal init.lua for testing
vim.g.did_load_filetypes = 1
vim.g.did_load_ftplugin = 1
vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[filetype plugin indent off]])
vim.cmd([[set packpath=/tmp/nvim/site]])

local package_root = '/tmp/nvim/site/pack'
local install_path = package_root .. '/packer/start/plenary.nvim'

-- Install plenary if not installed
if vim.fn.isdirectory(install_path) == 0 then
  vim.fn.system({
    'git',
    'clone',
    'https://github.com/nvim-lua/plenary.nvim',
    install_path,
  })
end

vim.cmd('packadd plenary.nvim')

-- Add current plugin to runtimepath
vim.opt.rtp:append('.')
vim.opt.rtp:append('./lua')

-- Required for running tests
vim.cmd([[runtime! plugin/plenary.vim]])

-- Mock nvim-cmp for testing
package.loaded['cmp'] = {
  lsp = {
    CompletionItemKind = {
      Property = 1,
      Class = 2,
      Keyword = 3,
    }
  }
}
