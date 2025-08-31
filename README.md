# AI-prompts

AI アシスタント用のプロンプトテンプレートと設定ファイル例を示します。

## リポジトリ構造

- `global/` - AI アシスタント設定ファイルの保存場所
  - `.claude/CLAUDE.md` - Claude Code 用のグローバル設定
  - `.continue/config.yaml` - Continue 用の設定ファイル

## ファイル形式とルール

### 言語設定

- 基本的に日本語での設定・コメント記述
- AI モデル設定やプロンプト定義も日本語ベース

## 設定の一貫性

このリポジトリの設定ファイルは Claude Code と Continue の両方で一貫したルールセットを維持しています。新しい設定を追加する際は、両方のファイル間で整合性を保ってください。

## 同期スクリプト

### sync-rules.ps1

Continue の `config.yaml` の rules セクションを Claude Code の `CLAUDE.md` の `## important_rules` セクションに同期する PowerShell スクリプトです。

**使用方法：**

```powershell
.\sync-rules.ps1
```

**機能：**

- `.continue/config.yaml` の rules セクションを抽出
- YAML の複数行記法 (`>-`) を Markdown 形式に変換
- `**タイトル**` 形式を `### タイトル` の見出しに変換
- `.claude/CLAUDE.md` の `## important_rules` セクションを置換
- UTF-8 (BOM なし) で保存

## TIPS

### グローバル設定ファイルの場所

- Claude Code のグローバル設定ファイルの場所は、`CLAUDE_CONFIG_DIR` 環境変数によってデフォルトの場所から変更設定可能です。
- Continue のグローバル設定ファイルの場所は、`CONTINUE_GLOBAL_DIR` 環境変数によってデフォルトの場所から変更設定可能です。
