#!/usr/bin/env python3
"""
Continue config.yaml の rules を抽出して Claude と Markdown 設定ファイルに同期する
"""

import re
from pathlib import Path


def extract_rules_from_yaml(yaml_path: Path) -> str:
    """config.yaml から rules セクションを抽出し Markdown に変換"""

    content = yaml_path.read_text(encoding='utf-8')

    # rules: から次のトップレベルキーまでを抽出
    match = re.search(r'^rules:\n(.*?)(?=^[a-zA-Z_]+:|\Z)', content, re.MULTILINE | re.DOTALL)
    if not match:
        raise ValueError("Rules section not found in config.yaml")

    rules_section = match.group(1)

    # 各行から先頭の2スペースを削除
    lines = rules_section.split('\n')
    processed_lines = []

    for line in lines:
        if line.startswith('  '):
            processed_lines.append(line[2:])
        elif line.strip() == '':
            processed_lines.append('')
        else:
            break

    # 末尾の空行を削除
    while processed_lines and processed_lines[-1].strip() == '':
        processed_lines.pop()

    # YAML から Markdown に変換
    markdown = convert_yaml_to_markdown(processed_lines)

    return markdown


def convert_yaml_to_markdown(lines: list[str]) -> str:
    """YAML 形式のルールを Markdown に変換"""

    result = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # - name: で始まるルールエントリを検出
        if match := re.match(r'^- name: (.+)$', line):
            i += 1

            # description をスキップ
            if i < len(lines) and re.match(r'^\s+description:', lines[i]):
                i += 1

            # rule: >- の処理
            if i < len(lines) and re.match(r'^\s+rule: >-$', lines[i]):
                i += 1  # rule: >- の次の行から開始

                # rule の内容を収集
                rule_lines = []
                base_indent = None

                while i < len(lines):
                    line = lines[i]

                    # 空行
                    if line.strip() == '':
                        rule_lines.append('')
                        i += 1
                        continue

                    # インデントチェック
                    if match := re.match(r'^(\s+)(.*)$', line):
                        indent = match.group(1)

                        # 基準インデント設定
                        if base_indent is None:
                            base_indent = indent

                        # 基準インデント以上の場合は内容として処理
                        if len(indent) >= len(base_indent) and line.startswith(base_indent):
                            # 基準インデントを削除
                            processed_line = line[len(base_indent):]
                            rule_lines.append(processed_line)
                            i += 1
                        else:
                            # インデントが少ない場合は終了
                            break
                    else:
                        # インデントがない行は終了
                        break

                # rule内容をMarkdownに変換
                if rule_lines:
                    rule_content = convert_rule_content_to_markdown(rule_lines)
                    if rule_content:
                        result.append(rule_content)

            continue
        else:
            # その他の行
            if line.strip():
                result.append(line)
            i += 1

    return '\n'.join(result)


def convert_rule_content_to_markdown(rule_lines: list[str]) -> str:
    """rule の内容を Markdown に変換（見出しを2段階下げる）"""

    result = []

    for line in rule_lines:
        if line.strip() == '':
            result.append('')
            continue

        # Markdown見出しを2段階下げる
        if match := re.match(r'^\s*(#{1,4})\s+(.*)$', line):
            hash_count = len(match.group(1))
            title_text = match.group(2)
            new_hash_count = hash_count + 2
            processed_line = '#' * new_hash_count + ' ' + title_text
            result.append(processed_line)
        else:
            result.append(line)

    return '\n'.join(result)


def update_claude_config(claude_path: Path, header_path: Path, rules_content: str):
    """Claude設定ファイルを更新"""

    header = header_path.read_text(encoding='utf-8').rstrip()
    claude_content = f"{header}\n\n## important_rules\n\n{rules_content}\n"

    # ディレクトリ作成
    claude_path.parent.mkdir(parents=True, exist_ok=True)

    # UTF-8 (BOM なし) で保存
    claude_path.write_text(claude_content, encoding='utf-8')


def update_markdown_prompt(markdown_path: Path, header_path: Path, rules_content: str):
    """Markdown プロンプトファイルを作成"""

    header = header_path.read_text(encoding='utf-8').rstrip()
    markdown_content = f"{header}\n\n## important_rules\n\n{rules_content}\n"

    # ディレクトリ作成
    markdown_path.parent.mkdir(parents=True, exist_ok=True)

    # UTF-8 (BOM なし) で保存
    markdown_path.write_text(markdown_content, encoding='utf-8')


def main():
    """メイン処理"""

    base_dir = Path(__file__).parent

    continue_config = base_dir / 'global' / '.continue' / 'config.yaml'
    claude_config = base_dir / 'global' / '.claude' / 'CLAUDE.md'
    claude_header = base_dir / 'claude-header.md'
    markdown_header = base_dir / 'markdown-header.md'
    markdown_output = base_dir / 'global' / 'markdown' / 'markdown.md'

    print("=== Continue Config Rules Sync Script ===")
    print(f"Continue Config: {continue_config}")
    print(f"Claude Config: {claude_config}")
    print(f"Claude Header: {claude_header}")
    print(f"Markdown Header: {markdown_header}")
    print(f"Markdown Output: {markdown_output}")
    print()

    # ファイル存在確認
    if not continue_config.exists():
        print(f"Error: File not found: {continue_config}")
        return 1
    if not claude_header.exists():
        print(f"Error: File not found: {claude_header}")
        return 1

    # rules セクション抽出
    print("Extracting rules section from Continue Config...")
    try:
        rules_content = extract_rules_from_yaml(continue_config)
    except Exception as e:
        print(f"Error: Failed to parse config.yaml: {e}")
        return 1

    line_count = len(rules_content.split('\n'))
    print(f"Extraction completed ({line_count} lines)")

    # Claude Config 更新
    print("Updating Claude Config with header and rules...")
    try:
        update_claude_config(claude_config, claude_header, rules_content)
        claude_success = True
    except Exception as e:
        print(f"Error: Failed to update CLAUDE.md: {e}")
        claude_success = False

    # Markdown プロンプト生成
    print("Creating generic LLM prompt (markdown.md)...")
    try:
        update_markdown_prompt(markdown_output, markdown_header, rules_content)
        markdown_success = True
    except Exception as e:
        print(f"Error: Failed to create markdown.md: {e}")
        markdown_success = False

    # 結果表示
    print()
    if claude_success and markdown_success:
        print("\033[92mSync completed successfully\033[0m")
        print()
        print("Updated files:")
        print(f"  {claude_config}")
        print(f"  {markdown_output}")
        return 0
    elif claude_success:
        print("\033[93mClaude Config updated, but markdown.md generation failed\033[0m")
        print()
        print("Updated file:")
        print(f"  {claude_config}")
        return 1
    elif markdown_success:
        print("\033[93mMarkdown.md created, but Claude Config update failed\033[0m")
        print()
        print("Updated file:")
        print(f"  {markdown_output}")
        return 1
    else:
        print("\033[93mSync failed\033[0m")
        return 1


if __name__ == '__main__':
    exit(main())
