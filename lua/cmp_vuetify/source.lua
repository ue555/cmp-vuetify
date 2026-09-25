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

--- Load Vuetify components from project
--- @param bufnr number Buffer number
local function load_vuetify_components(bufnr)
  local root = utils.find_project_root(bufnr)

  if not root then
    utils.notify('Could not find project root (package.json)', vim.log.levels.DEBUG)
    return {}, {}, nil
  end

  local project_cache = get_cache(root)

  -- Check if cache is still valid
  local current_time = os.time()
  if project_cache.timestamp > 0 and (current_time - project_cache.timestamp) < 60 then
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

  return tags or {}, attributes or {}, version
end

--- Determine completion context
--- @return string 'tag'|'attribute'|'none'
local function get_completion_context(text, col)
  local before_cursor = text:sub(1, col)

  -- Find last < and > positions
  local last_lt_pos = before_cursor:reverse():find('<')
  local last_gt_pos = before_cursor:reverse():find('>')

  -- Convert reversed positions to actual positions
  if last_lt_pos then
    last_lt_pos = col - last_lt_pos + 1
  end
  if last_gt_pos then
    last_gt_pos = col - last_gt_pos + 1
  end

  -- Outside any tag
  if not last_lt_pos or (last_gt_pos and last_gt_pos > last_lt_pos) then
    return 'none'
  end

  -- Inside a tag (between < and cursor, with no > in between)
  local tag_content = before_cursor:sub(last_lt_pos)

  -- Check if it's a closing tag
  if tag_content:match('^</%s*$') or tag_content:match('^</[%w%-]*$') then
    return 'tag'
  end

  -- Match: <tagname followed by space (attribute context)
  if tag_content:match('^<[%w%-]+%s+') then
    return 'attribute'
  end

  -- Match: <tagname without space (tag name context)
  if tag_content:match('^<[%w%-]*$') then
    return 'tag'
  end

  return 'none'
end

--- Extract the current tag name from the line
local function get_current_tag(text, col)
  local before_cursor = text:sub(1, col)

  -- Find last < position
  local last_lt_pos = before_cursor:reverse():find('<')
  if not last_lt_pos then
    return nil
  end

  last_lt_pos = col - last_lt_pos + 1
  local tag_content = before_cursor:sub(last_lt_pos)

  -- Match tag name after <
  local tag = tag_content:match('^<([%w%-]+)')
  return tag
end

--- Get text from tag opening to cursor for multi-line support
--- @param bufnr number Buffer number
--- @param cursor_line number Cursor line number (1-indexed)
--- @param cursor_col number Cursor column (1-indexed, byte position)
--- @return string Text from tag opening to cursor
--- @return number Column offset in the combined text
local function get_tag_context(bufnr, cursor_line, cursor_col)
  -- Get current line
  local lines = vim.api.nvim_buf_get_lines(bufnr, cursor_line - 1, cursor_line, false)
  if #lines == 0 then
    return '', 0
  end

  local current_line = lines[1]
  local before_cursor = current_line:sub(1, cursor_col - 1)

  -- Check if there's a < on the current line
  if before_cursor:find('<[^>]*$') then
    return before_cursor, #before_cursor
  end

  -- Look back for tag opening (up to 20 lines)
  local lookback_lines = math.min(20, cursor_line - 1)
  if lookback_lines == 0 then
    return before_cursor, #before_cursor
  end

  -- Get previous lines
  local prev_lines = vim.api.nvim_buf_get_lines(bufnr, cursor_line - 1 - lookback_lines, cursor_line - 1, false)

  -- Search backwards for the last unclosed <
  local combined_text = ''
  local tag_start_found = false

  for i = #prev_lines, 1, -1 do
    local line = prev_lines[i]
    combined_text = line .. '\n' .. combined_text

    -- Check if this line contains an unclosed <
    local lt_count = 0
    local gt_count = 0
    for _ in line:gmatch('<') do
      lt_count = lt_count + 1
    end
    for _ in line:gmatch('>') do
      gt_count = gt_count + 1
    end

    if lt_count > gt_count then
      tag_start_found = true
      break
    end
  end

  if tag_start_found then
    combined_text = combined_text .. before_cursor
    local offset = #combined_text
    return combined_text, offset
  else
    return before_cursor, #before_cursor
  end
end

--- Complete function - provides completion items
function source:complete(params, callback)
  local bufnr = params.context.bufnr
  local cursor = params.context.cursor
  local cursor_line = cursor.line + 1  -- Convert to 1-indexed
  local cursor_col = cursor.col

  -- Get text from tag opening to cursor (multi-line support)
  local context_text, col_offset = get_tag_context(bufnr, cursor_line, cursor_col)

  local tags, attributes = load_vuetify_components(bufnr)

  -- If no tags loaded, return empty
  if not next(tags) then
    callback({ items = {}, isIncomplete = false })
    return
  end

  local items = {}
  local context = get_completion_context(context_text, col_offset)

  if context == 'attribute' then
    -- Provide attribute completion
    local current_tag = get_current_tag(context_text, col_offset)
    current_tag = current_tag and components.to_kebab_case(current_tag)

    if current_tag and tags[current_tag] then
      local tag_info = tags[current_tag]
      local tag_attrs = tag_info.attributes or {}

      for _, attr_name in ipairs(tag_attrs) do
        local attr_info = attributes[current_tag .. '/' .. attr_name] or {}
        local doc_value = attr_info.description ~= '' and attr_info.description
          or ('Attribute for ' .. current_tag)

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
