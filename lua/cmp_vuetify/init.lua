local M = {}

-- Default configuration
local config = {
  version = nil, -- Auto-detect from package.json
  notification_level = vim.log.levels.WARN,
}

--- Setup function for user configuration
--- @param opts table|nil User configuration options
function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend('force', config, opts)
end

--- Get current configuration
--- @return table Current configuration
function M.get_config()
  return config
end

--- Clear cache for current or specific project
--- @param root string|nil Project root path, or nil for current project
function M.clear_cache(root)
  local source = require('cmp_vuetify.source')
  local instance = source.new()

  if root == 'all' then
    -- Clear all caches
    instance:clear_cache()
  elseif root then
    -- Clear specific project cache
    instance:clear_cache(root)
  else
    -- Clear current project cache
    local utils = require('cmp_vuetify.utils')
    local current_root = utils.find_project_root(0)
    if current_root then
      instance:clear_cache(current_root)
    end
  end
end

--- Clear all project caches
function M.clear_all_caches()
  M.clear_cache('all')
end

--- Reload metadata for current project
function M.reload()
  M.clear_cache()
end

return M
