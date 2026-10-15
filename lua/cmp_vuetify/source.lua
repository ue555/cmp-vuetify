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
  -- Activate when any part of a compound filetype (e.g. vue.html) matches
  local filetypes = require('cmp_vuetify').get_config().filetypes
  for filetype in vim.gsplit(vim.bo.filetype, '.', { plain = true }) do
    if vim.tbl_contains(filetypes, filetype) then
      return true
    end
  end
  return false
end

--- Get trigger characters
function source:get_trigger_characters()
  return { '<', '-', ' ', '@', ':' }
end

--- Get the keyword pattern. It includes the `@`, `:`, `v-on:`, and `v-bind:`
--- prefixes and `:` inside event names such as `update:model-value`, so
--- the whole word is replaced on confirmation.
function source:get_keyword_pattern()
  return [[\%(@\|:\|v-on:\|v-bind:\)\?[[:alnum:]_-]*\%([:.][[:alnum:]_-]*\)*]]
end

--- Cache for loaded tags and attributes (multi-project support)
local cache = {}

--- Get or create cache for a project root
local function get_cache(root)
  if not cache[root] then
    cache[root] = {
      tags = {},
      attributes = {},
      events = {},
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
  local package_root = utils.find_vuetify_package(root)
  local stat = package_root and (vim.uv or vim.loop).fs_stat(package_root .. '/package.json')
  return stat and stat.mtime.sec or nil
end

--- Load Vuetify components from project
--- @param bufnr number Buffer number
--- @return table tags
--- @return table attributes
--- @return table events
local function load_vuetify_components(bufnr)
  local root = utils.find_project_root(bufnr)

  if not root then
    utils.notify('Could not find project root (package.json)', vim.log.levels.DEBUG)
    return {}, {}, {}
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
    return project_cache.tags, project_cache.attributes, project_cache.events
  end

  -- Detect Vuetify version
  local version = utils.detect_vuetify_version(root)
  if not version then
    utils.notify('Could not detect Vuetify version in project', vim.log.levels.DEBUG)
    return {}, {}, {}
  end

  utils.notify('Detected Vuetify v' .. version, vim.log.levels.DEBUG)

  -- Load metadata
  local tags, attributes, events = utils.load_vuetify_metadata(root, version)

  -- Update cache
  project_cache.tags = tags or {}
  project_cache.attributes = attributes or {}
  project_cache.events = events or {}
  project_cache.version = version
  project_cache.timestamp = current_time
  project_cache.package_mtime = package_mtime

  return project_cache.tags, project_cache.attributes, project_cache.events
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
--- @return string|nil Text from the open tag's `<` to the cursor
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
    return 'tag', nil, tag_content
  end

  -- Tag name followed by whitespace
  local tag = tag_content:match('^<([%w%-]+)%s')
  if tag then
    return 'attribute', tag, tag_content
  end

  return 'none', nil, nil
end

--- Check whether a prop type is a plain union that includes boolean, so the
--- prop can be written without a value (e.g. `string | boolean`). Complex
--- TypeScript types that only mention boolean inside are excluded.
--- @param value_type string|nil
--- @return boolean
local function accepts_bare_attribute(value_type)
  if not value_type or value_type:find('[%[%]%(%){}<>\n]') then
    return false
  end

  for member in vim.gsplit(value_type, '|', { plain = true }) do
    if vim.trim(member) == 'boolean' then
      return true
    end
  end
  return false
end

--- Parse the attributes already written in the open tag.
--- @param tag_content string Text from the open tag's `<` to the cursor
--- @param model table|nil Prop and event bound by v-model
--- @return table used_props Set of written prop names (kebab-case)
--- @return table used_events Set of written event names (kebab-case)
--- @return string typing Attribute name being typed at the cursor
local function parse_written_attributes(tag_content, model)
  local body = tag_content:gsub('^<[%w%-]+', ''):gsub('"[^"]*"', ''):gsub("'[^']*'", '')
  local typing = body:match('[^%s=]*$')
  body = body:sub(1, #body - #typing)

  local used_props = {}
  local used_events = {}

  for name in body:gmatch('[^%s=]+') do
    local event = name:match('^@(.+)') or name:match('^v%-on:(.+)')
    local model_arg = name:match('^v%-model:([^.]+)')

    if event then
      -- Strip modifiers such as .stop or .prevent
      used_events[components.to_kebab_case((event:gsub('%..*$', '')))] = true
    elseif model_arg then
      local prop = components.to_kebab_case(model_arg)
      used_props[prop] = true
      used_events['update:' .. prop] = true
    elseif name == 'v-model' or name:match('^v%-model%.') then
      if model then
        used_props[model.prop] = true
        used_events[model.event] = true
      end
    else
      -- Strip :, v-bind:, and . prefixes and modifiers such as .sync
      local prop = name:match('^:(.+)') or name:match('^v%-bind:(.+)') or name:match('^%.(.+)') or name
      used_props[components.to_kebab_case((prop:gsub('%..*$', '')))] = true
    end
  end

  return used_props, used_events, typing
end

--- Build markdown documentation for a completion item
--- @param description string|nil
--- @param fallback string Text used when the description is empty
--- @param info table Attribute or event info
--- @return table
local function build_documentation(description, fallback, info)
  local value = (description and description ~= '') and description or fallback

  if info.type then
    value = value .. '\n\n_Type: `' .. info.type .. '`_'
  end

  if info.default ~= nil then
    value = value .. '\n\n_Default: `' .. tostring(info.default) .. '`_'
  end

  if info.documentation_url then
    value = value .. '\n\n[Vuetify documentation](' .. info.documentation_url .. ')'
  end

  return { kind = 'markdown', value = value }
end

--- Build prop and event completion items for a tag
--- @param tag_name string Kebab-case tag name
--- @param tag_info table
--- @param attributes table
--- @param events table
--- @param tag_content string Text from the open tag's `<` to the cursor
--- @return table items
local function build_attribute_items(tag_name, tag_info, attributes, events, tag_content)
  local kinds = require('cmp').lsp.CompletionItemKind
  local used_props, used_events, typing = parse_written_attributes(tag_content, tag_info.model)
  local items = {}

  -- Events after @ or v-on:
  local event_prefix = typing:match('^@') or typing:match('^v%-on:')
  if event_prefix then
    for _, event_name in ipairs(tag_info.events or {}) do
      if not used_events[event_name] then
        local event_info = events[tag_name .. '/' .. event_name] or {}
        table.insert(items, {
          label = event_prefix .. event_name,
          kind = kinds.Event,
          documentation = build_documentation(event_info.description, 'Event for ' .. tag_name, event_info),
          insertText = event_prefix .. event_name .. '="${1}"',
          insertTextFormat = 2, -- Snippet format
        })
      end
    end
    return items
  end

  -- Props, bound with : or v-bind: when typed
  local bind_prefix = typing:match('^:') or typing:match('^v%-bind:') or ''
  for _, attr_name in ipairs(tag_info.attributes or {}) do
    if not used_props[attr_name] then
      local attr_info = attributes[tag_name .. '/' .. attr_name] or {}
      local label = bind_prefix .. attr_name
      local bare = bind_prefix == '' and accepts_bare_attribute(attr_info.type)

      table.insert(items, {
        label = label,
        kind = kinds.Property,
        documentation = build_documentation(attr_info.description, 'Attribute for ' .. tag_name, attr_info),
        insertText = bare and label or (label .. '="${1}"'),
        insertTextFormat = 2, -- Snippet format
      })
    end
  end

  return items
end

--- Build component completion items
--- @param tags table
--- @param tag_content string Text from `<` or `</` to the cursor
--- @return table items
local function build_tag_items(tags, tag_content)
  -- Use PascalCase names (VBtn) when the typed name starts with an uppercase letter
  local pascal_case = tag_content:match('^</?%u') ~= nil
  local items = {}

  for tag_name, tag_info in pairs(tags) do
    -- Only show Vuetify components (starting with v-)
    if tag_name:match('^v%-') then
      local doc_value = tag_info.description ~= '' and tag_info.description or 'Vuetify component'

      if tag_info.documentation_url then
        doc_value = doc_value .. '\n\n[Vuetify documentation](' .. tag_info.documentation_url .. ')'
      end

      table.insert(items, {
        label = pascal_case and tag_info.original_name or tag_name,
        kind = require('cmp').lsp.CompletionItemKind.Class,
        documentation = {
          kind = 'markdown',
          value = doc_value,
        },
      })
    end
  end

  return items
end

--- Complete function - provides completion items
function source:complete(params, callback)
  local bufnr = params.context.bufnr
  local cursor = params.context.cursor
  local cursor_line = cursor.line + 1 -- Convert to 1-indexed
  local cursor_col = cursor.col

  -- Determine context from the tag open at the cursor (multi-line support)
  local context, current_tag, tag_content = get_completion_context(bufnr, cursor_line, cursor_col)

  local tags, attributes, events = load_vuetify_components(bufnr)

  -- If no tags loaded, return empty
  if not next(tags) or not tag_content then
    callback({ items = {}, isIncomplete = false })
    return
  end

  local items = {}
  local is_incomplete = false

  if context == 'attribute' then
    current_tag = current_tag and components.to_kebab_case(current_tag)
    if current_tag and tags[current_tag] then
      items = build_attribute_items(current_tag, tags[current_tag], attributes, events, tag_content)
    end
  elseif context == 'tag' then
    items = build_tag_items(tags, tag_content)
    -- Right after `<` or `</`, the case of the name is not known yet. Ask
    -- nvim-cmp to complete again on the next keystroke so that typing `V`
    -- switches the candidates to PascalCase names.
    is_incomplete = tag_content:match('^</?$') ~= nil
  end

  callback({ items = items, isIncomplete = is_incomplete })
end

return source
