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
- **PascalCase support**: Complete props for `<VBtn` with kebab-case conversion
- **Type information**: Shows prop types, defaults, and documentation URLs
- **Multi-line tags**: Complete props across multiple lines
- **Smart caching**: 60-second per-project cache for performance
- **Workspace dependencies**: Detects versions even with `workspace:*` or `catalog:` syntax

## Requirements

- Neovim 0.7 or later
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- Vuetify 2, 3, or 4 installed in `node_modules`

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

### packer.nvim

```lua
use {
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
}
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

Boolean props are inserted without quotes:

```vue
<v-btn disabled>
```

Non-boolean props are inserted as snippets:

```vue
<v-btn color="${1}">
```

### PascalCase support

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
})
```

## How it works

1. **Find project root**: Searches for `package.json` from the current Vue file
2. **Detect version**: Reads the exact version from `node_modules/vuetify/package.json`
3. **Load metadata**: Reads Vuetify's `web-types.json` file
4. **Parse components**: Extracts component names, props, types, and documentation URLs
5. **Convert names**: Transforms PascalCase (`VBtn`) to kebab-case (`v-btn`)
6. **Provide completion**: Returns components and props based on cursor context

### Version detection priority

1. **Installed package** (highest priority): `node_modules/vuetify/package.json`
   - Works even with `workspace:*` or `catalog:` dependencies
2. **Project dependencies**: `package.json` in project root
3. **Manual configuration**: `version` in setup options

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

### Test coverage

- ✅ **Component parsing**: web-types.json to completion data conversion
- ✅ **Name conversion**: PascalCase to kebab-case transformation
- ✅ **Version detection**: All version detection methods including workspace:*
- ✅ **Metadata loading**: Reading and parsing web-types.json
- ✅ **Component completion**: Version-specific component filtering
- ✅ **Prop completion**: Component-specific prop filtering and snippet generation
- ✅ **PascalCase tags**: Prop completion for PascalCase component tags
- ✅ **Multi-line tags**: Prop completion across multiple lines
- ✅ **Unknown tags**: No Vuetify completions for non-Vuetify tags

All 20 tests pass with real Vuetify 2, 3, and 4 metadata.

## License

MIT
