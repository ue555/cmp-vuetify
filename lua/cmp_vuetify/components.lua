local M = {}

local function is_list(value)
  if vim.islist then
    return vim.islist(value)
  end

  return vim.tbl_islist(value)
end

--- Convert a PascalCase or camelCase identifier to kebab-case.
--- @param name string
--- @return string
function M.to_kebab_case(name)
  return name
    :gsub('(%u)(%u%l)', '%1-%2')
    :gsub('(%l%d)(%u)', '%1-%2')
    :gsub('(%l)(%u)', '%1-%2')
    :gsub('_', '-')
    :lower()
end

local function get_value_type(attribute)
  if type(attribute.value) == 'table' then
    local value_type = attribute.value.type

    if type(value_type) == 'string' then
      return value_type
    end

    if type(value_type) == 'table' and is_list(value_type) then
      local types = {}
      for _, item in ipairs(value_type) do
        if type(item) == 'string' then
          table.insert(types, item)
        end
      end

      if #types > 0 then
        return table.concat(types, ' | ')
      end
    end
  end

  return nil
end

--- Convert Vuetify web-types metadata to completion tables.
--- @param metadata table Decoded web-types.json data
--- @return table tags
--- @return table attributes
function M.from_web_types(metadata)
  local html = metadata
    and metadata.contributions
    and metadata.contributions.html

  if not html or type(html.tags) ~= 'table' then
    return {}, {}
  end

  local tags = {}
  local attributes = {}

  for _, tag in ipairs(html.tags) do
    if type(tag.name) == 'string' then
      local tag_name = M.to_kebab_case(tag.name)
      local attribute_names = {}

      for _, attribute in ipairs(tag.attributes or {}) do
        if type(attribute.name) == 'string' then
          local attribute_name = M.to_kebab_case(attribute.name)
          table.insert(attribute_names, attribute_name)
          attributes[tag_name .. '/' .. attribute_name] = {
            description = attribute.description or '',
            documentation_url = attribute['doc-url'],
            type = get_value_type(attribute),
            default = attribute.default,
          }
        end
      end

      tags[tag_name] = {
        description = tag.description or '',
        documentation_url = tag['doc-url'],
        attributes = attribute_names,
        original_name = tag.name,
      }
    end
  end

  return tags, attributes
end

return M
