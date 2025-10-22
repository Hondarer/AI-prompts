# AI-prompts

AI アシスタント用のプロンプトテンプレートと設定ファイル群を管理するリポジトリです。

## リポジトリ構造

```text
AI-prompts/
├── CLAUDE.md               # このリポジトリ用の Claude Code 設定
├── README.md               # このドキュメント
├── LICENSE                 # ライセンスファイル
├── claude-header.md        # Claude Code 用設定のヘッダー部分
├── markdown-header.md      # 汎用 Markdown プロンプトのヘッダー部分
├── sync-rules.ps1          # ルール同期スクリプト
├── deploy.ps1              # 設定ファイルのデプロイスクリプト
└── global/                 # グローバル設定ファイル群
    ├── .claude/
    │   └── CLAUDE.md       # Claude Code 用グローバル設定
    ├── .continue/
    │   └── config.yaml     # Continue 用設定ファイル
    └── markdown/
        └── markdown.md     # 汎用 LLM プロンプト (Markdown 用)
```

## ファイル形式とルール

### 言語設定

すべての設定ファイルとコメントは日本語で記述します。AI モデルに対するプロンプト定義も日本語ベースです。

### 設定の一貫性

このリポジトリは、Continue の `config.yaml` の rules セクションを信頼できる情報源 (Single Source of Truth) として扱い、そこから他の設定ファイルを自動生成することで一貫性を維持しています。

## スクリプト

### sync-rules.ps1

Continue の `config.yaml` の rules セクションを基に、Claude Code 用の `CLAUDE.md` と汎用 LLM プロンプト `markdown.md` を生成します。

**使用方法**

```powershell
.\sync-rules.ps1
```

**機能**

- `global/.continue/config.yaml` の rules セクションを抽出
- YAML の複数行記法 (`>-`) を Markdown 形式に変換
- `**タイトル**` 形式を `### タイトル` の見出しに変換
- `global/.claude/CLAUDE.md` の `## important_rules` セクションを置換
- `global/markdown/markdown.md` を生成
- すべてのファイルを UTF-8 (BOM なし) で保存

### deploy.ps1

生成された設定ファイルをユーザーのグローバル設定ディレクトリにデプロイします。

**使用方法**

```powershell
.\deploy.ps1
```

**機能**

- 実行前に `sync-rules.ps1` を自動的に実行してルールを同期
- `global/.claude/CLAUDE.md` をユーザーの Claude Code 設定ディレクトリにコピー
- `global/.continue/config.yaml` をユーザーの Continue 設定ディレクトリにコピー
- 環境変数 `CLAUDE_CONFIG_DIR` と `CONTINUE_GLOBAL_DIR` を優先的に使用
- デプロイ結果をサマリ表示

## TIPS

### グローバル設定ファイルの場所

Claude Code と Continue は、それぞれ環境変数によってグローバル設定ファイルの場所を変更できます。

- **Claude Code**: `CLAUDE_CONFIG_DIR` 環境変数
  - デフォルト: `%USERPROFILE%\.claude` (Windows) / `~/.claude` (macOS/Linux)
- **Continue**: `CONTINUE_GLOBAL_DIR` 環境変数
  - デフォルト: `%USERPROFILE%\.continue` (Windows) / `~/.continue` (macOS/Linux)

### 設定の更新手順

1. `global/.continue/config.yaml` の rules セクションを編集
2. `sync-rules.ps1` を実行して他のファイルを生成
3. `deploy.ps1` を実行してユーザー環境に反映
