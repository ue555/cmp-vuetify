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
    assert.equal('vuetify', instance:get_debug_name())
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
    assert.equal('variant="${1}"', items.variant.insertText)
    assert.is_not_nil(items.stacked)
    assert.equal('stacked', items.stacked.insertText)
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

  it('ignores > and < inside quoted attribute values', function()
    local root = create_project('3', 'vuetify-3-web-types.json')

    for _, line in ipairs({
      '<v-btn @click="() => go()" ',
      '<v-btn v-if="a > b" ',
      "<v-btn v-if='a < b' ",
      '<p>{{ a < b }}</p><v-btn ',
      '<!-- <div> --><v-btn ',
    }) do
      local items = complete(instance, root, { line }, 1, line)
      ---@diagnostic disable-next-line: redundant-parameter
      assert.is_not_nil(items.variant, line)
    end
  end)

  it('ignores code in a script block above the template', function()
    local root = create_project('3', 'vuetify-3-web-types.json')
    local lines = {
      '<script setup lang="ts">',
      'for (let i = 0; i<n; i++) {}',
      "// don't stop",
      '</script>',
      '<template>',
      '  <p>{{ unclosed',
      '  <v-btn ',
    }

    local items = complete(instance, root, lines, #lines, lines[#lines])
    assert.is_not_nil(items.variant)
  end)

  it('does not complete inside quoted attribute values or after a closed tag', function()
    local root = create_project('3', 'vuetify-3-web-types.json')

    assert.same({}, complete(instance, root, { '<v-btn color="' }, 1, '<v-btn color="'))
    assert.same({}, complete(instance, root, { '<v-btn>text ' }, 1, '<v-btn>text '))
  end)

  it('completes attributes in a multi-line tag with arrow functions and comparisons', function()
    local root = create_project('3', 'vuetify-3-web-types.json')
    local items = complete(instance, root, {
      '<v-btn',
      '  @click="() => go()"',
      '  v-if="a > b"',
      '  ',
    }, 4, '  ')

    assert.is_not_nil(items.variant)
  end)

  it('completes attributes in a tag spanning more than 20 lines', function()
    local root = create_project('3', 'vuetify-3-web-types.json')
    local lines = { '<v-btn' }
    for i = 1, 30 do
      table.insert(lines, '  data-a' .. i .. '="1"')
    end
    table.insert(lines, '  ')

    local items = complete(instance, root, lines, #lines, '  ')
    assert.is_not_nil(items.variant)
  end)

  it('reloads metadata when Vuetify is installed after a failed load', function()
    local root = create_project('3', 'vuetify-3-web-types.json')
    local package_path = root .. '/node_modules/vuetify/package.json'
    local package_lines = vim.fn.readfile(package_path)
    vim.fn.delete(package_path)

    assert.same({}, complete(instance, root, { '<v-' }, 1, '<v-'))

    vim.fn.writefile(package_lines, package_path)
    local items = complete(instance, root, { '<v-' }, 1, '<v-')
    assert.is_not_nil(items['v-btn'])
  end)

  it('completes in a workspace package with Vuetify hoisted to the root', function()
    local workspace = create_project('3', 'vuetify-3-web-types.json')
    local app = workspace .. '/packages/app'
    vim.fn.mkdir(app .. '/src', 'p')
    vim.fn.writefile({ '{"dependencies":{"vuetify":"workspace:*"}}' }, app .. '/package.json')

    local items = complete(instance, app .. '/src', { '<v-btn ' }, 1, '<v-btn ')
    assert.is_not_nil(items.variant)
  end)

  it('completes events after @ and v-on:', function()
    local root = create_project('3', 'vuetify-3-web-types.json')

    local items = complete(instance, root, { '<v-btn @' }, 1, '<v-btn @')
    assert.equal('@click="${1}"', items['@click'].insertText)
    assert.is_not_nil(items['@update:model-value'])
    assert.equal(23, items['@click'].kind)
    assert.is_nil(items.color)

    items = complete(instance, root, { '<v-btn v-on:up' }, 1, '<v-btn v-on:up')
    assert.equal('v-on:update:model-value="${1}"', items['v-on:update:model-value'].insertText)
  end)

  it('completes bound props after : and v-bind:', function()
    local root = create_project('3', 'vuetify-3-web-types.json')

    local items = complete(instance, root, { '<v-btn :' }, 1, '<v-btn :')
    assert.equal(':color="${1}"', items[':color'].insertText)
    assert.equal(':stacked="${1}"', items[':stacked'].insertText)
    assert.is_nil(items['@click'])

    items = complete(instance, root, { '<v-btn v-bind:co' }, 1, '<v-btn v-bind:co')
    assert.equal('v-bind:color="${1}"', items['v-bind:color'].insertText)
  end)

  it('excludes props and events already written in the tag', function()
    local root = create_project('3', 'vuetify-3-web-types.json')
    local lines = { '<v-btn', '  color="red"', '  :variant="v"', '  @click.stop="go"', '  ' }

    local items = complete(instance, root, lines, #lines, '  ')
    assert.is_nil(items.color)
    assert.is_nil(items.variant)
    assert.is_not_nil(items.density)

    lines[#lines] = '  @'
    items = complete(instance, root, lines, #lines, '  @')
    assert.is_nil(items['@click'])
    assert.is_not_nil(items['@update:model-value'])
  end)

  it('excludes the prop and event bound by v-model', function()
    local root = create_project('3', 'vuetify-3-web-types.json')

    local items = complete(instance, root, { '<v-btn v-model="x" ' }, 1, '<v-btn v-model="x" ')
    assert.is_nil(items['model-value'])
    assert.is_not_nil(items.color)

    items = complete(instance, root, { '<v-btn v-model="x" @' }, 1, '<v-btn v-model="x" @')
    assert.is_nil(items['@update:model-value'])
    assert.is_not_nil(items['@click'])
  end)

  it('keeps the prop being typed in the candidates', function()
    local root = create_project('3', 'vuetify-3-web-types.json')
    local items = complete(instance, root, { '<v-btn col' }, 1, '<v-btn col')

    assert.is_not_nil(items.color)
  end)

  it('inserts props whose type is a union with boolean without a value', function()
    local root = create_project('3', 'vuetify-3-web-types.json')
    local items = complete(instance, root, { '<v-btn ' }, 1, '<v-btn ')

    assert.equal('loading', items.loading.insertText)
    assert.equal('rules="${1}"', items.rules.insertText)
    assert.equal('model-value="${1}"', items['model-value'].insertText)

    root = create_project('2', 'vuetify-2-web-types.json')
    instance:clear_cache()
    items = complete(instance, root, { '<v-btn ' }, 1, '<v-btn ')
    assert.equal('loading', items.loading.insertText)
    assert.equal('elevation="${1}"', items.elevation.insertText)
  end)

  it('completes PascalCase component names when typed in PascalCase', function()
    local root = create_project('3', 'vuetify-3-web-types.json')

    local items = complete(instance, root, { '<VB' }, 1, '<VB')
    assert.is_not_nil(items.VBtn)
    assert.is_nil(items['v-btn'])

    items = complete(instance, root, { '</VB' }, 1, '</VB')
    assert.is_not_nil(items.VBtn)

    items = complete(instance, root, { '<v-' }, 1, '<v-')
    assert.is_not_nil(items['v-btn'])
    assert.is_nil(items.VBtn)
  end)

  it('is available for configured filetypes including compound filetypes', function()
    local config = require('cmp_vuetify').get_config()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)

    vim.bo.filetype = 'vue.html'
    assert.is_true(instance:is_available())

    vim.bo.filetype = 'html'
    assert.is_false(instance:is_available())

    config.filetypes = { 'vue', 'html' }
    assert.is_true(instance:is_available())
    config.filetypes = { 'vue' }

    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it('returns no attributes for unknown tags', function()
    local root = create_project('3', 'vuetify-3-web-types.json')
    local items = complete(instance, root, { '<not-vuetify ' }, 1, '<not-vuetify ')

    assert.same({}, items)
  end)
end)
