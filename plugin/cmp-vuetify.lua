-- Plugin entry point for cmp-vuetify
-- This file is automatically loaded by Neovim

if vim.g.loaded_cmp_vuetify then
  return
end
vim.g.loaded_cmp_vuetify = true

-- Register the source with nvim-cmp. When nvim-cmp is not loaded yet (e.g.
-- lazy-loaded on InsertEnter), retry on InsertEnter until it succeeds.
local cmp_vuetify = require('cmp_vuetify')
if not cmp_vuetify.register() then
  vim.api.nvim_create_autocmd('InsertEnter', {
    group = vim.api.nvim_create_augroup('cmp_vuetify_register', { clear = true }),
    callback = function()
      -- Returning true deletes the autocmd
      return cmp_vuetify.register()
    end,
  })
end
