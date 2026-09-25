local source = require('cmp_vuetify.source')

local temporary_directories = {}

local function create_project(version, fixture)
  local root = vim.fn.tempname()
  table.insert(temporary_directories, root)
  vim.fn.mkdir(root .. '/node_modules/vuetify/dist/json', 'p')
  vim.fn.writefile({ '{"dependencies":{"vuetify":"' .. version .. '.0.0"}}' }, root .. '/package.json')
  vim.fn.writefile({
    '{"name":"vuetify","version":"' .. version .. '.0.0","web-types":"dist/json/web-types.json"}',
  }, root .. '/node_modules/vuetify/package.json')
  vim.fn.writefile(
    vim.fn.readfile(vim.fn.getcwd() .. '/tests/fixtures/' .. fixture),
    root .. '/node_modules/vuetify/dist/json/web-types.json'
  )
  return root
end

local function complete(instance, root, lines, row, before_cursor)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, root .. '/Component.vue')
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(bufnr)
  vim.bo.filetype = 'vue'

  local result
  instance:complete({
    context = {
      bufnr = bufnr,
      cursor = {
        line = row - 1,
        row = row,
        col = #before_cursor + 1,
      },
      cursor_line = lines[row],
      cursor_before_line = before_cursor,
    },
  }, function(value)
    result = value
  end)

  local items = {}
  for _, item in ipairs(result.items) do
    items[item.label] = item
  end

  vim.api.nvim_buf_delete(bufnr, { force = true })
  return items
end

describe('source', function()
  local instance

  before_each(function()
    require('cmp_vuetify').get_config().version = nil
    instance = source.new()
    instance:clear_cache()
  end)

  after_each(function()
    vim.cmd.enew({ bang = true })
    for _, path in ipairs(temporary_directories) do
      vim.fn.delete(path, 'rf')
    end
    temporary_directories = {}
  end)

  it('exposes the source interface', function()
    assert.equals('vuetify', instance:get_debug_name())
    assert.is_true(vim.tbl_contains(instance:get_trigger_characters(), '<'))

    vim.bo.filetype = 'vue'
    assert.is_true(instance:is_available())
    vim.bo.filetype = 'lua'
    assert.is_false(instance:is_available())
  end)

  it('returns Vuetify 2 tags and excludes Vuetify 3 tags', function()
    local root = create_project('2', 'vuetify-2-web-types.json')
    local items = complete(instance, root, { '<v-' }, 1, '<v-')

    assert.is_not_nil(items['v-content'])
    assert.is_not_nil(items['v-tab-item'])
    assert.is_nil(items['v-main'])
    assert.is_nil(items['v-card-item'])
  end)

  it('returns current Vuetify 3 components including former labs components', function()
    local root = create_project('3', 'vuetify-3-web-types.json')
    local items = complete(instance, root, { '<v-' }, 1, '<v-')

    assert.is_not_nil(items['v-main'])
    assert.is_not_nil(items['v-date-picker'])
    assert.is_not_nil(items['v-treeview'])
    assert.is_not_nil(items['v-calendar'])
    assert.is_not_nil(items['v-data-iterator'])
    assert.is_nil(items['v-content'])
    assert.is_nil(items['v-tab-item'])
  end)

  it('returns official Vuetify 4 components without invented entries', function()
    local root = create_project('4', 'vuetify-4-web-types.json')
    local items = complete(instance, root, { '<v-' }, 1, '<v-')

    assert.is_not_nil(items['v-icon-btn'])
    assert.is_nil(items['v-icon-transition'])
    assert.is_nil(items['v-tab-item'])
  end)

  it('returns component-specific props and snippets', function()
    local root = create_project('3', 'vuetify-3-web-types.json')
    local items = complete(instance, root, { '<v-btn ' }, 1, '<v-btn ')

    assert.is_not_nil(items.variant)
    assert.equals('variant="${1}"', items.variant.insertText)
    assert.is_not_nil(items.stacked)
    assert.equals('stacked', items.stacked.insertText)
    assert.is_nil(items.depressed)
    assert.is_nil(items.fab)
  end)

  it('supports PascalCase component attributes', function()
    local root = create_project('4', 'vuetify-4-web-types.json')
    local items = complete(instance, root, { '<VBtn ' }, 1, '<VBtn ')

    assert.is_not_nil(items['hover-elevation'])
    assert.is_nil(items.depressed)
  end)

  it('completes attributes in a multi-line tag', function()
    local root = create_project('2', 'vuetify-2-web-types.json')
    local items = complete(instance, root, { '<v-btn', '  ' }, 2, '  ')

    assert.is_not_nil(items.depressed)
    assert.is_nil(items.variant)
  end)

  it('returns no attributes for unknown tags', function()
    local root = create_project('3', 'vuetify-3-web-types.json')
    local items = complete(instance, root, { '<not-vuetify ' }, 1, '<not-vuetify ')

    assert.same({}, items)
  end)
end)
