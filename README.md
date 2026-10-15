# cmp-vuetify

[日本語](./README_ja.md)

An [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) source for Vuetify component and prop completion.

This plugin reads the official `web-types.json` metadata distributed with the installed Vuetify package, providing accurate completion for Vuetify 2, 3, and 4.

## Features

- **Supports Vuetify 2, 3, and 4** with automatic version detection
- **Official metadata**: Uses Vuetify's bundled `web-types.json` for accurate completion
- **Component completion**: All components defined in the installed Vuetify version
- **Component-specific props**: Only shows props that actually exist for each component
- **Version-aware**: Automatically filters out components and props from other versions
  - Vuetify 2: `v-content`, `v-tab-item`, `depressed`, `fab`
  - Vuetify 3+: `v-main`, `v-card-item`, `variant`, `density`
  - Vuetify 4: `v-icon-btn`, `hover-elevation`
- **Event completion**: Complete component events after `@` or `v-on:` (e.g. `@click:clear`, `@update:model-value`)
- **Bound props**: Complete props after `:` or `v-bind:`
- **Skips written attributes**: Props and events already written in the tag (including those bound by `v-model`) are not suggested again
- **PascalCase support**: Complete `<VBtn` as PascalCase component names, and props for PascalCase tags
- **Type information**: Shows prop types, defaults, and documentation URLs
- **Multi-line tags**: Complete props across multiple lines
- **Smart caching**: 60-second per-project cache for performance
- **Workspace dependencies**: Detects versions even with `workspace:*` or `catalog:` syntax, and finds Vuetify hoisted to the workspace root

## Requirements

- Neovim 0.10 or later
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- Vuetify 2, 3, or 4 installed in `node_modules` (the project's own or a parent directory's, such as a hoisted workspace root)
  - Yarn Plug'n'Play (no `node_modules`) is not supported. Use `nodeLinker: node-modules` in `.yarnrc.yml`

The plugin has been tested with Neovim 0.11.5.

## Installation

### lazy.nvim

```lua
{
  "hrsh7th/nvim-cmp",
  dependencies = {
    "ue555/cmp-vuetify",
  },
  config = function()
    local cmp = require("cmp")

    cmp.setup({
      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "vuetify" },
      }),
    })
  end,
}
```

### pckr.nvim

```lua
require("pckr").add({
  {
    "hrsh7th/nvim-cmp",
    requires = {
      "ue555/cmp-vuetify",
    },
    config = function()
      local cmp = require("cmp")

      cmp.setup({
        sources = {
          { name = "nvim_lsp" },
          { name = "vuetify" },
        },
      })
    end,
  },
})
```

### nvpm

Add to your nvpm `config.json`:

```json
{
  "plugins": [
    {
      "url": "hrsh7th/nvim-cmp",
      "dependencies": ["ue555/cmp-vuetify"]
    }
  ]
}
```

Then configure in your `init.lua`:

```lua
local cmp = require("cmp")

cmp.setup({
  sources = {
    { name = "nvim_lsp" },
    { name = "vuetify" },
  },
})
```

## Usage

### Component completion

Type `<v-` to see all available Vuetify components:

```vue
<template>
  <v-
  <!-- Shows: v-btn, v-card, v-data-table, v-app-bar, ... -->
</template>
```

Closing tags are also completed:

```vue
<template>
  </v-
  <!-- Shows: v-btn, v-card, ... -->
</template>
```

### Prop completion

Type a space after the component name to see its props:

```vue
<template>
  <v-btn
  <!-- Shows: color, variant, size, disabled, ... -->
</template>
```

Boolean props, including simple unions with boolean such as `string | boolean`,
are inserted without a value:

```vue
<v-btn disabled loading>
```

Other props are inserted as snippets:

```vue
<v-btn color="${1}">
```

Props already written in the tag are not suggested again. Props and events
bound by `v-model` (`model-value` / `update:model-value` in Vuetify 3+,
`value` and its event in Vuetify 2) are also skipped.

### Bound props

Type `:` or `v-bind:` to complete props as bindings. Values are always
inserted as snippets:

```vue
<v-btn :color="${1}">
```

### Event completion

Type `@` or `v-on:` to see the component's events:

```vue
<template>
  <v-text-field @
  <!-- Shows: @click:clear, @update:model-value, ... -->
</template>
```

### PascalCase support

Component names typed in PascalCase are completed in PascalCase:

```vue
<template>
  <VTe
  <!-- Shows: VTextField, VTextarea, ... -->
</template>
```

Props are also completed for PascalCase component tags:

```vue
<template>
  <VBtn
  <!-- Shows kebab-case props: color, variant, size, ... -->
</template>
```

### Multi-line tags

Prop completion works across multiple lines:

```vue
<template>
  <v-btn
    color="primary"

  <!-- Cursor here - props are still completed -->
</template>
```

## Configuration

Configuration is optional. All settings have sensible defaults:

```lua
require("cmp_vuetify").setup({
  -- Vuetify version (2, 3, or 4)
  -- Only used if the installed package version cannot be detected
  -- Default: nil (auto-detect from node_modules)
  version = nil,

  -- Notification level for warnings and errors
  -- Default: vim.log.levels.WARN
  notification_level = vim.log.levels.WARN,

  -- Filetypes where completion is enabled
  -- Compound filetypes such as "vue.html" match by each part
  -- Default: { "vue" }
  filetypes = { "vue" },
})
```

The source is registered with nvim-cmp automatically. If nvim-cmp is loaded
later (for example, lazy-loaded on `InsertEnter`), registration is retried on
`InsertEnter`, and `setup()` also registers it.

## How it works

1. **Find project root**: Searches for `package.json` from the current Vue file
2. **Find installed Vuetify**: Searches `node_modules/vuetify` from the project root up through parent directories, like Node.js module resolution
3. **Detect version**: Reads the exact version from the installed `vuetify/package.json`
4. **Load metadata**: Reads Vuetify's `web-types.json` file
5. **Parse components**: Extracts component names, props, types, and documentation URLs
6. **Convert names**: Transforms PascalCase (`VBtn`) to kebab-case (`v-btn`)
7. **Provide completion**: Returns components and props based on cursor context

### Version detection priority

1. **Installed package** (highest priority): `node_modules/vuetify/package.json`
   - Works even with `workspace:*` or `catalog:` dependencies
   - Also finds Vuetify hoisted to a parent workspace root (npm/yarn workspaces)
2. **Manual configuration**: `version` in setup options
   - Used only when the installed package version cannot be read
3. **Project dependencies**: `package.json` in project root

The `version` option does not load metadata for a different Vuetify version.
Completion data is always read from the installed package's
`web-types.json`.

### Why web-types.json?

Vuetify officially maintains `web-types.json` for IDE integration. By reading this file directly:

- ✅ Always accurate for the installed version
- ✅ Includes all components (even those that move between labs and stable)
- ✅ No manual maintenance of component lists
- ✅ Automatically includes new components when you upgrade Vuetify
- ✅ Type information and documentation links

## Cache API

Results are cached per project for 60 seconds to improve performance.

### Clear cache for current project

```lua
require("cmp_vuetify").clear_cache()
```

### Clear cache for specific project

```lua
require("cmp_vuetify").clear_cache("/path/to/project")
```

### Clear all project caches

```lua
require("cmp_vuetify").clear_all_caches()
```

### Reload metadata for current project

```lua
require("cmp_vuetify").reload()
```

## Testing

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim):

```bash
make test
```

### Lint and format

Formatting uses [StyLua](https://github.com/JohnnyMorganz/StyLua) (`.stylua.toml`)
and diagnostics use [lua-language-server](https://github.com/LuaLS/lua-language-server) (`.luarc.json`):

```bash
make lint    # Check formatting and diagnostics
make format  # Format Lua files
```

### Test coverage

- ✅ **Component parsing**: web-types.json to completion data conversion
- ✅ **Name conversion**: PascalCase to kebab-case transformation
- ✅ **Version detection**: All version detection methods including workspace:*
- ✅ **Metadata loading**: Reading and parsing web-types.json
- ✅ **Component completion**: Version-specific component filtering
- ✅ **Prop completion**: Component-specific prop filtering and snippet generation
- ✅ **PascalCase tags**: Prop completion for PascalCase component tags
- ✅ **Multi-line tags**: Prop completion across multiple lines
- ✅ **Symbols in attribute values**: Prop completion after `@click="() => x"` or `v-if="a > b"`
- ✅ **Cache refresh**: Metadata reloads immediately after Vuetify is installed
- ✅ **Workspaces**: Finds Vuetify hoisted to a parent workspace root
- ✅ **Events**: Event completion after `@` and `v-on:`
- ✅ **Written attributes**: Props and events already in the tag, including `v-model`, are skipped
- ✅ **Boolean unions**: Props such as `string | boolean` are inserted without a value
- ✅ **Filetypes and registration**: `filetypes` option and nvim-cmp source registration
- ✅ **Unknown tags**: No Vuetify completions for non-Vuetify tags

All 41 tests pass using reduced `web-types.json` fixtures for Vuetify 2, 3,
and 4. The completion path was also verified separately with the published
Vuetify 2.7.2, 3.13.5, and 4.2.2 packages.

## License

MIT
