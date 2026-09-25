local utils = require('cmp_vuetify.utils')

local temporary_directories = {}

local function create_project(version, fixture, dependency)
  local root = vim.fn.tempname()
  table.insert(temporary_directories, root)
  vim.fn.mkdir(root .. '/node_modules/vuetify/dist/json', 'p')
  vim.fn.writefile({
    vim.json.encode({
      dependencies = { vuetify = dependency or ('^' .. version .. '.0.0') },
    }),
  }, root .. '/package.json')
  vim.fn.writefile({
    vim.json.encode({
      name = 'vuetify',
      version = version .. '.0.0',
      ['web-types'] = 'dist/json/web-types.json',
    }),
  }, root .. '/node_modules/vuetify/package.json')
  vim.fn.writefile(
    vim.fn.readfile(vim.fn.getcwd() .. '/tests/fixtures/' .. fixture),
    root .. '/node_modules/vuetify/dist/json/web-types.json'
  )
  return root
end

describe('utils', function()
  before_each(function()
    require('cmp_vuetify').get_config().version = nil
  end)

  after_each(function()
    for _, path in ipairs(temporary_directories) do
      vim.fn.delete(path, 'rf')
    end
    temporary_directories = {}
  end)

  describe('read_json_file', function()
    it('returns nil for non-existent and invalid files', function()
      assert.is_nil(utils.read_json_file('/non/existent/file.json'))

      local path = vim.fn.tempname()
      vim.fn.writefile({ '{invalid' }, path)
      assert.is_nil(utils.read_json_file(path))
      vim.fn.delete(path)
    end)
  end)

  describe('detect_vuetify_version', function()
    it('prefers the installed package version for workspace dependencies', function()
      local root = create_project('3', 'vuetify-3-web-types.json', 'workspace:*')
      assert.equals(3, utils.detect_vuetify_version(root))
    end)

    it('detects a supported version from dependencies without node_modules', function()
      local root = vim.fn.tempname()
      table.insert(temporary_directories, root)
      vim.fn.mkdir(root, 'p')
      vim.fn.writefile({ '{"devDependencies":{"vuetify":"^4.1.0"}}' }, root .. '/package.json')

      assert.equals(4, utils.detect_vuetify_version(root))
    end)

    it('rejects unsupported configured versions', function()
      require('cmp_vuetify').get_config().version = 5
      assert.is_nil(utils.detect_vuetify_version('/non/existent/path'))
    end)
  end)

  describe('load_vuetify_metadata', function()
    it('loads the installed package web-types path', function()
      local root = create_project('2', 'vuetify-2-web-types.json')
      local tags, attributes = utils.load_vuetify_metadata(root, 2)

      assert.is_not_nil(tags['v-content'])
      assert.is_true(vim.tbl_contains(tags['v-btn'].attributes, 'depressed'))
      assert.equals('boolean', attributes['v-btn/depressed'].type)
    end)

    it('returns nil when the installed package metadata is unavailable', function()
      local root = vim.fn.tempname()
      table.insert(temporary_directories, root)
      vim.fn.mkdir(root, 'p')

      local tags, attributes = utils.load_vuetify_metadata(root, 3)
      assert.is_nil(tags)
      assert.is_nil(attributes)
    end)
  end)
end)
