# cmp-vuetify

[English](./README.md)

Vuetifyコンポーネントとpropsの補完機能を提供する[nvim-cmp](https://github.com/hrsh7th/nvim-cmp)プラグインです。

インストールされているVuetifyパッケージに同梱された公式の`web-types.json`メタデータを読み込むことで、Vuetify 2、3、4の正確な補完を提供します。

## 特徴

- **Vuetify 2、3、4に対応** - バージョン自動検出
- **公式メタデータを使用** - Vuetifyの`web-types.json`から正確な補完情報を取得
- **コンポーネント補完** - インストール済みVuetifyバージョンの全コンポーネント
- **コンポーネント固有のprops** - 各コンポーネントに実際に存在するpropsのみを表示
- **バージョン対応** - 他バージョンのコンポーネントとpropsを自動的に除外
  - Vuetify 2: `v-content`, `v-tab-item`, `depressed`, `fab`
  - Vuetify 3+: `v-main`, `v-card-item`, `variant`, `density`
  - Vuetify 4: `v-icon-btn`, `hover-elevation`
- **PascalCase対応** - `<VBtn`でもkebab-caseのpropsを補完
- **型情報表示** - propsの型、デフォルト値、ドキュメントURLを表示
- **複数行タグ対応** - 複数行に渡るタグでもpropsを補完
- **スマートキャッシュ** - プロジェクトごとに60秒間キャッシュ
- **workspace依存関係対応** - `workspace:*`や`catalog:`でもバージョン検出

## 必要要件

- Neovim 0.7以降
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- `node_modules`にインストールされたVuetify 2、3、4のいずれか

## インストール

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

## 使用方法

### コンポーネント補完

`<v-`と入力すると、利用可能な全Vuetifyコンポーネントが表示されます：

```vue
<template>
  <v-
  <!-- 表示: v-btn, v-card, v-data-table, v-app-bar, ... -->
</template>
```

閉じタグも補完されます：

```vue
<template>
  </v-
  <!-- 表示: v-btn, v-card, ... -->
</template>
```

### props補完

コンポーネント名の後にスペースを入力すると、そのコンポーネントのpropsが表示されます：

```vue
<template>
  <v-btn
  <!-- 表示: color, variant, size, disabled, ... -->
</template>
```

boolean型のpropsはクォートなしで挿入されます：

```vue
<v-btn disabled>
```

boolean型以外のpropsはsnippet形式で挿入されます：

```vue
<v-btn color="${1}">
```

### PascalCase対応

PascalCaseのコンポーネントタグでもpropsが補完されます：

```vue
<template>
  <VBtn
  <!-- kebab-caseのpropsを表示: color, variant, size, ... -->
</template>
```

### 複数行タグ対応

複数行に渡るタグでもprops補完が動作します：

```vue
<template>
  <v-btn
    color="primary"

  <!-- カーソル位置 - propsが補完される -->
</template>
```

## 設定

設定は任意です。すべての設定にデフォルト値があります：

```lua
require("cmp_vuetify").setup({
  -- Vuetifyのバージョン (2, 3, 4)
  -- インストールされているパッケージのバージョンを検出できない場合のみ使用
  -- デフォルト: nil (node_modulesから自動検出)
  version = nil,

  -- 警告とエラーの通知レベル
  -- デフォルト: vim.log.levels.WARN
  notification_level = vim.log.levels.WARN,
})
```

## 動作の仕組み

1. **プロジェクトルートの検索**: 現在のVueファイルから`package.json`を検索
2. **バージョン検出**: `node_modules/vuetify/package.json`から正確なバージョンを読み取り
3. **メタデータ読み込み**: Vuetifyの`web-types.json`ファイルを読み込み
4. **コンポーネント解析**: コンポーネント名、props、型、ドキュメントURLを抽出
5. **名前変換**: PascalCase (`VBtn`) をkebab-case (`v-btn`) に変換
6. **補完提供**: カーソル位置に応じてコンポーネントまたはpropsを返す

### バージョン検出の優先順位

1. **インストール済みパッケージ**（最優先）: `node_modules/vuetify/package.json`
   - `workspace:*`や`catalog:`依存関係でも動作
2. **プロジェクトの依存関係**: プロジェクトルートの`package.json`
3. **手動設定**: setupオプションの`version`

### なぜweb-types.jsonを使用するのか？

Vuetifyは公式にIDE統合用の`web-types.json`を提供しています。このファイルを直接読み込むことで：

- ✅ インストールされているバージョンで常に正確
- ✅ すべてのコンポーネントを含む（labsと安定版を移動するコンポーネントも）
- ✅ コンポーネントリストの手動メンテナンスが不要
- ✅ Vuetifyをアップグレードすると自動的に新しいコンポーネントを含む
- ✅ 型情報とドキュメントリンク付き

## キャッシュAPI

パフォーマンス向上のため、プロジェクトごとに60秒間キャッシュを保持します。

### 現在のプロジェクトのキャッシュをクリア

```lua
require("cmp_vuetify").clear_cache()
```

### 特定プロジェクトのキャッシュをクリア

```lua
require("cmp_vuetify").clear_cache("/path/to/project")
```

### 全プロジェクトのキャッシュをクリア

```lua
require("cmp_vuetify").clear_all_caches()
```

### 現在のプロジェクトのメタデータを再読み込み

```lua
require("cmp_vuetify").reload()
```

## テスト

テストには[plenary.nvim](https://github.com/nvim-lua/plenary.nvim)を使用します：

```bash
make test
```

### テストカバレッジ

- ✅ **コンポーネント解析**: web-types.jsonから補完データへの変換
- ✅ **名前変換**: PascalCaseからkebab-caseへの変換
- ✅ **バージョン検出**: workspace:*を含む全バージョン検出方法
- ✅ **メタデータ読み込み**: web-types.jsonの読み取りと解析
- ✅ **コンポーネント補完**: バージョン固有のコンポーネントフィルタリング
- ✅ **props補完**: コンポーネント固有のpropsフィルタリングとsnippet生成
- ✅ **PascalCaseタグ**: PascalCaseコンポーネントタグのprops補完
- ✅ **複数行タグ**: 複数行に渡るprops補完
- ✅ **不明なタグ**: Vuetifyでないタグには補完を返さない

実際のVuetify 2、3、4のメタデータを使用した全20テストが成功しています。

## 実装の詳細

### 変更履歴

このプラグインは当初、手書きのコンポーネント定義を使用していましたが、以下の理由で公式`web-types.json`を使用する方式に変更されました：

- **精度の向上**: 実際にインストールされているVuetifyバージョンに含まれるコンポーネントとpropsを正確に反映
- **メンテナンス不要**: Vuetifyの更新に追従するための手動メンテナンスが不要
- **存在しないコンポーネントの除外**: 以前の定義に含まれていた存在しないコンポーネント（`v-icon-transition`など）を自動的に除外
- **バージョン固有props**: 各バージョンのコンポーネントに実際に定義されているpropsのみを補完

詳細は[変更点.md](./変更点.md)を参照してください。

### テスト結果

実際のVuetifyパッケージを使用した検証結果：

| Vuetify | コンポーネント数 | v-btnのprops数 |
|---------|---------------:|---------------:|
| 2.7.2   | 146            | 49             |
| 3.13.5  | 198            | 41             |
| 4.2.2   | 210            | 42             |

詳細は[テスト結果.md](./テスト結果.md)を参照してください。

## ライセンス

MIT
