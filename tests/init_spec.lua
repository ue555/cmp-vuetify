describe('cmp_vuetify', function()
  local original_cmp

  before_each(function()
    original_cmp = package.loaded['cmp']
    package.loaded['cmp_vuetify'] = nil
  end)

  after_each(function()
    package.loaded['cmp'] = original_cmp
    package.loaded['cmp_vuetify'] = nil
  end)

  describe('register', function()
    it('returns false when nvim-cmp is not available', function()
      package.loaded['cmp'] = nil
      package.preload['cmp'] = function()
        error('module not found')
      end

      assert.is_false(require('cmp_vuetify').register())
      package.preload['cmp'] = nil
    end)

    it('registers the source only once', function()
      local registered = {}
      package.loaded['cmp'] = {
        register_source = function(name)
          table.insert(registered, name)
        end,
      }

      local cmp_vuetify = require('cmp_vuetify')
      assert.is_true(cmp_vuetify.register())
      assert.is_true(cmp_vuetify.register())
      assert.same({ 'vuetify' }, registered)
    end)

    it('registers the source from setup', function()
      local registered = {}
      package.loaded['cmp'] = {
        register_source = function(name)
          table.insert(registered, name)
        end,
      }

      require('cmp_vuetify').setup({})
      assert.same({ 'vuetify' }, registered)
    end)
  end)
end)
