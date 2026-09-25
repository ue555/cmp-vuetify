local M = {}

--- Notify with plugin prefix
--- @param msg string Message to display
--- @param level number Log level (vim.log.levels)
function M.notify(msg, level)
  local config = require('cmp_vuetify').get_config()
  if level >= config.notification_level then
    vim.notify('[cmp-vuetify] ' .. msg, level)
  end
end

--- Find project root by searching for package.json
--- @param bufnr number|nil Buffer number, defaults to the current buffer
--- @return string|nil Project root path or nil if not found
function M.find_project_root(bufnr)
  local current_file = vim.api.nvim_buf_get_name(bufnr or 0)
  if current_file == '' then
    return nil
  end

  local current_dir = vim.fn.fnamemodify(current_file, ':p:h')
  local root = vim.fn.findfile('package.json', current_dir .. ';')

  if root ~= '' then
    return vim.fn.fnamemodify(root, ':p:h')
  end

  return nil
end

--- Read and parse JSON file
--- @param path string Path to JSON file
--- @return table|nil Parsed JSON data or nil on error
function M.read_json_file(path)
  local file = io.open(path, 'r')
  if not file then
    return nil
  end

  local content = file:read('*all')
  file:close()

  local ok, decoded = pcall(vim.fn.json_decode, content)
  if not ok then
    return nil
  end

  return decoded
end

--- Detect Vuetify version from package.json
--- @param root string Project root path
--- @return number|nil Vuetify version (2, 3, or 4) or nil if not found
function M.detect_vuetify_version(root)
  local config = require('cmp_vuetify').get_config()

  -- Prefer the installed package because dependency declarations may use
  -- aliases such as workspace:* or catalog:, and it is the metadata source.
  local installed_package = M.read_json_file(root .. '/node_modules/vuetify/package.json')
  if installed_package and type(installed_package.version) == 'string' then
    local installed_major = tonumber(installed_package.version:match('^(%d+)'))
    if installed_major == 2 or installed_major == 3 or installed_major == 4 then
      return installed_major
    end
  end

  -- Use the configured version only when the installed package version
  -- cannot be read.
  if config.version then
    if config.version == 2 or config.version == 3 or config.version == 4 then
      return config.version
    end

    M.notify('Unsupported configured Vuetify version: ' .. tostring(config.version), vim.log.levels.WARN)
    return nil
  end

  local package_data = M.read_json_file(root .. '/package.json')

  if not package_data then
    return nil
  end

  -- Check both dependencies and devDependencies
  local deps = package_data.dependencies or {}
  local dev_deps = package_data.devDependencies or {}

  local vuetify_version = deps.vuetify or dev_deps.vuetify

  if not vuetify_version then
    return nil
  end

  -- Parse version string (e.g., "^3.0.0" -> 3)
  if type(vuetify_version) ~= 'string' then
    return nil
  end

  local major_version = vuetify_version:match('^[^%d]*(%d+)')
  if major_version then
    local version = tonumber(major_version)
    if version == 2 or version == 3 or version == 4 then
      return version
    end
  end

  return nil
end

--- Load Vuetify component metadata
--- @param root string Project root path
--- @param version number Vuetify version (2, 3, or 4)
--- @return table|nil, table|nil Tags and attributes tables, or nil on error
function M.load_vuetify_metadata(root, version)
  local components_data = require('cmp_vuetify.components')
  local package_root = root .. '/node_modules/vuetify'
  local package_data = M.read_json_file(package_root .. '/package.json')

  if not package_data then
    M.notify('Could not read installed Vuetify package.json', vim.log.levels.WARN)
    return nil, nil
  end

  local web_types_path = package_data['web-types'] or 'dist/json/web-types.json'
  local metadata = M.read_json_file(package_root .. '/' .. web_types_path)

  if not metadata then
    M.notify('Could not read Vuetify web-types metadata for v' .. version, vim.log.levels.WARN)
    return nil, nil
  end

  return components_data.from_web_types(metadata)
end

return M
