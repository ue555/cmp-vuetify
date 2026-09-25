local components = require('cmp_vuetify.components')

local function read_fixture(name)
  local path = vim.fn.getcwd() .. '/tests/fixtures/' .. name
  return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
end

describe('components', function()
  describe('to_kebab_case', function()
    it('converts component and prop names', function()
      assert.equals('v-btn', components.to_kebab_case('VBtn'))
      assert.equals('v-otp-input', components.to_kebab_case('VOtpInput'))
      assert.equals('hover-elevation', components.to_kebab_case('hoverElevation'))
      assert.equals('aria-label', components.to_kebab_case('aria-label'))
    end)
  end)

  describe('from_web_types', function()
    it('loads Vuetify 2 components and props', function()
      local tags, attributes = components.from_web_types(read_fixture('vuetify-2-web-types.json'))

      assert.is_not_nil(tags['v-content'])
      assert.is_not_nil(tags['v-tab-item'])
      assert.is_nil(tags['v-main'])
      assert.is_true(vim.tbl_contains(tags['v-btn'].attributes, 'depressed'))
      assert.equals('boolean', attributes['v-btn/depressed'].type)
      assert.equals('number | string', attributes['v-btn/elevation'].type)
    end)

    it('loads Vuetify 3 components without obsolete entries', function()
      local tags = components.from_web_types(read_fixture('vuetify-3-web-types.json'))

      assert.is_not_nil(tags['v-main'])
      assert.is_not_nil(tags['v-card-item'])
      assert.is_not_nil(tags['v-date-picker'])
      assert.is_not_nil(tags['v-treeview'])
      assert.is_nil(tags['v-content'])
      assert.is_nil(tags['v-tab-item'])
    end)

    it('loads Vuetify 4 names and kebab-case props', function()
      local tags, attributes = components.from_web_types(read_fixture('vuetify-4-web-types.json'))

      assert.is_not_nil(tags['v-icon-btn'])
      assert.is_nil(tags['v-icon-transition'])
      assert.is_true(vim.tbl_contains(tags['v-btn'].attributes, 'hover-elevation'))
      assert.equals('string | number', attributes['v-btn/hover-elevation'].type)
    end)

    it('preserves official descriptions and documentation URLs', function()
      local tags = components.from_web_types(read_fixture('vuetify-3-web-types.json'))

      assert.equals('Button component', tags['v-btn'].description)
      assert.equals('https://vuetifyjs.com/api/v-btn/', tags['v-btn'].documentation_url)
    end)

    it('returns empty tables for malformed metadata', function()
      local tags, attributes = components.from_web_types({})

      assert.same({}, tags)
      assert.same({}, attributes)
    end)
  end)
end)
