-- Plugin entry point for cmp-vuetify
-- This file is automatically loaded by Neovim

-- Register the source with nvim-cmp
local ok, cmp = pcall(require, 'cmp')
if ok then
  local source = require('cmp_vuetify.source')
  cmp.register_source('vuetify', source.new())
end
