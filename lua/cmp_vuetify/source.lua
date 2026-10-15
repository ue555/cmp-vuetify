local utils = require('cmp_vuetify.utils')
local components = require('cmp_vuetify.components')

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

--- Get the source name
function source:get_debug_name()
  return 'vuetify'
end

--- Check if the source is available for the current buffer
function source:is_available()
  -- Only activate in Vue files
  local filetype = vim.bo.filetype
  return filetype == 'vue'
end

--- Get trigger characters
function source:get_trigger_characters()
  return { '<', '-', ' ' }
end

--- Cache for loaded tags and attributes (multi-project support)
local cache = {}

--- Get or create cache for a project root
local function get_cache(root)
  if not cache[root] then
    cache[root] = {
      tags = {},
      attributes = {},
      version = nil,
      timestamp = 0,
    }
  end
  return cache[root]
end

--- Clear cache for a specific root or all roots
function source:clear_cache(root)
  if root then
    cache[root] = nil
  else
    cache = {}
  end
end

--- Get the modification time of the installed Vuetify package.json
--- @param root string Project root path
--- @return number|nil Modification time in seconds, or nil if not installed
local function get_package_mtime(root)
  local stat = (vim.uv or vim.loop).fs_stat(root .. '/node_modules/vuetify/package.json')
  return stat and stat.mtime.sec or nil
end

--- Load Vuetify components from project
--- @param bufnr number Buffer number
local function load_vuetify_components(bufnr)
  local root = utils.find_project_root(bufnr)

  if not root then
    utils.notify('Could not find project root (package.json)', vim.log.levels.DEBUG)
    return {}, {}, nil
  end

  local project_cache = get_cache(root)

  -- Check if cache is still valid. Installing or upgrading Vuetify changes
  -- the installed package.json, which invalidates the cache immediately.
  local current_time = os.time()
  local package_mtime = get_package_mtime(root)
  if
    project_cache.timestamp > 0
    and (current_time - project_cache.timestamp) < 60
    and project_cache.package_mtime == package_mtime
  then
    return project_cache.tags, project_cache.attributes, project_cache.version
  end

  -- Detect Vuetify version
  local version = utils.detect_vuetify_version(root)
  if not version then
    utils.notify('Could not detect Vuetify version in project', vim.log.levels.DEBUG)
    return {}, {}, nil
  end

  utils.notify('Detected Vuetify v' .. version, vim.log.levels.DEBUG)

  -- Load metadata
  local tags, attributes = utils.load_vuetify_metadata(root, version)

  -- Update cache
  project_cache.tags = tags or {}
  project_cache.attributes = attributes or {}
  project_cache.version = version
  project_cache.timestamp = current_time
  project_cache.package_mtime = package_mtime

  return tags or {}, attributes or {}, version
end

--- Maximum number of lines scanned before the cursor to find the open tag
local MAX_LOOKBACK_LINES = 200

--- Scan text and return the content of the tag still open at the end.
--- Quoted attribute values, comments, and mustache interpolations are
--- skipped so that `<` and `>` inside them do not affect the result.
--- @param text string Text ending at the cursor
--- @return string|nil Text from the open tag's `<` to the end, or nil
local function find_open_tag(text)
  local pos = 1
  local len = #text

  while pos <= len do
    -- Text state: look for the next tag opening or interpolation
    local start, _, token = text:find('([<{])', pos)
    if not start then
      return nil
    end

    if token == '{' then
      if text:sub(start, start + 1) == '{{' then
        -- An unclosed interpolation is skipped as plain text
        local close = text:find('}}', start + 2, true)
        pos = close and close + 2 or start + 2
      else
        pos = start + 1
      end
    elseif text:sub(start, start + 3) == '<!--' then
      local close = text:find('-->', start + 4, true)
      if not close then
        return nil
      end
      pos = close + 3
    elseif start == len or text:sub(start + 1, start + 1):match('[%a/]') then
      -- Tag state: skip quoted values until the closing `>`
      local tag_pos = start + 1
      while true do
        local stop, _, char = text:find('(["\'>])', tag_pos)
        if not stop then
          return text:sub(start)
        end

        if char == '>' then
          pos = stop + 1
          break
        end

        local close = text:find(char, stop + 1, true)
        if not close then
          -- Cursor is inside a quoted attribute value
          return nil
        end
        tag_pos = close + 1
      end
    else
      -- `<` not followed by a tag name, such as `a < b`
      pos = start + 1
    end
  end

  return nil
end

--- Determine completion context at the cursor
--- @param bufnr number Buffer number
--- @param cursor_line number Cursor line number (1-indexed)
--- @param cursor_col number Cursor column (1-indexed, byte position)
--- @return string 'tag'|'attribute'|'none'
--- @return string|nil Current tag name in attribute context
local function get_completion_context(bufnr, cursor_line, cursor_col)
  local first_line = math.max(0, cursor_line - 1 - MAX_LOOKBACK_LINES)
  local lines = vim.api.nvim_buf_get_lines(bufnr, first_line, cursor_line, false)
  if #lines == 0 then
    return 'none', nil
  end

  lines[#lines] = lines[#lines]:sub(1, cursor_col - 1)

  -- Start after the last <script> or <style> block above the cursor, since
  -- their code may contain `<` and quotes that are not HTML.
  for i = #lines - 1, 1, -1 do
    if lines[i]:match('^%s*</script%s*>') or lines[i]:match('^%s*</style%s*>') then
      lines = vim.list_slice(lines, i + 1)
      break
    end
  end
  local tag_content = find_open_tag(table.concat(lines, '\n'))
  if not tag_content then
    return 'none', nil
  end

  -- Closing tag or tag name being typed
  if tag_content:match('^</?[%w%-]*$') then
    return 'tag', nil
  end

  -- Tag name followed by whitespace
  local tag = tag_content:match('^<([%w%-]+)%s')
  if tag then
    return 'attribute', tag
  end

  return 'none', nil
end

--- Complete function - provides completion items
function source:complete(params, callback)
  local bufnr = params.context.bufnr
  local cursor = params.context.cursor
  local cursor_line = cursor.line + 1 -- Convert to 1-indexed
  local cursor_col = cursor.col

  -- Determine context from the tag open at the cursor (multi-line support)
  local context, current_tag = get_completion_context(bufnr, cursor_line, cursor_col)

  local tags, attributes = load_vuetify_components(bufnr)

  -- If no tags loaded, return empty
  if not next(tags) then
    callback({ items = {}, isIncomplete = false })
    return
  end

  local items = {}

  if context == 'attribute' then
    -- Provide attribute completion
    current_tag = current_tag and components.to_kebab_case(current_tag)

    if current_tag and tags[current_tag] then
      local tag_info = tags[current_tag]
      local tag_attrs = tag_info.attributes or {}

      for _, attr_name in ipairs(tag_attrs) do
        local attr_info = attributes[current_tag .. '/' .. attr_name] or {}
        local doc_value = attr_info.description ~= '' and attr_info.description or ('Attribute for ' .. current_tag)

        if attr_info.type then
          doc_value = doc_value .. '\n\n_Type: `' .. attr_info.type .. '`_'
        end

        if attr_info.default ~= nil then
          doc_value = doc_value .. '\n\n_Default: `' .. tostring(attr_info.default) .. '`_'
        end

        if attr_info.documentation_url then
          doc_value = doc_value .. '\n\n[Vuetify documentation](' .. attr_info.documentation_url .. ')'
        end

        local is_boolean = attr_info.type == 'boolean'

        table.insert(items, {
          label = attr_name,
          kind = require('cmp').lsp.CompletionItemKind.Property,
          documentation = {
            kind = 'markdown',
            value = doc_value,
          },
          insertText = is_boolean and attr_name or (attr_name .. '="${1}"'),
          insertTextFormat = 2, -- Snippet format
        })
      end
    end
  elseif context == 'tag' then
    -- Provide tag completion
    for tag_name, tag_info in pairs(tags) do
      -- Only show Vuetify components (starting with v-)
      if tag_name:match('^v%-') then
        local doc_value = tag_info.description or 'Vuetify component'

        if tag_info.documentation_url then
          doc_value = doc_value .. '\n\n[Vuetify documentation](' .. tag_info.documentation_url .. ')'
        end

        table.insert(items, {
          label = tag_name,
          filterText = tag_name .. ' ' .. (tag_info.original_name or ''),
          kind = require('cmp').lsp.CompletionItemKind.Class,
          documentation = {
            kind = 'markdown',
            value = doc_value,
          },
        })
      end
    end
  end

  callback({ items = items, isIncomplete = false })
end

return source
