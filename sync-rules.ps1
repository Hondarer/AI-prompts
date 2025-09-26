#Requires -Version 5.1
<#
.SYNOPSIS
    .continue/config.yaml の rules エントリを .claude/CLAUDE.md の ## important_rules セクションに置換する

.DESCRIPTION
    .continue/config.yaml ファイルから rules セクションを抽出し、
    .claude/CLAUDE.md ファイルの ## important_rules セクションと置換します。
    UTF-8 (BOM なし) でファイルを保存します。

.PARAMETER ContinueConfigPath
    .continue/config.yaml ファイルのパス (デフォルト: global/.continue/config.yaml)

.PARAMETER ClaudeConfigPath
    .claude/CLAUDE.md ファイルのパス (デフォルト: global/.claude/CLAUDE.md)

.EXAMPLE
    .\sync-rules.ps1
    デフォルトパスのファイルを使用して同期を実行

.EXAMPLE
    .\sync-rules.ps1 -ContinueConfigPath "path/to/config.yaml" -ClaudeConfigPath "path/to/CLAUDE.md"
    指定されたパスのファイルを使用して同期を実行
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ContinueConfigPath = "global\.continue\config.yaml",
    
    [Parameter(Mandatory = $false)]
    [string]$ClaudeConfigPath = "global\.claude\CLAUDE.md"
)

# UTF-8 (BOM なし) エンコーディングを設定
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false


function Test-FileExists {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "Error: File not found: $FilePath"
        return $false
    }
    return $true
}

function Convert-YamlToMarkdown {
    param([string[]]$Lines)

    $result = @()
    $i = 0

    while ($i -lt $Lines.Count) {
        $line = $Lines[$i]

        # 構造化されたルールエントリの開始を検出
        if ($line -match '^- name: (.+)$') {
            $ruleName = $matches[1]
            $i++

            # description と rule を抽出
            $description = ""
            $ruleContent = ""

            # description を取得
            if ($i -lt $Lines.Count -and $Lines[$i] -match '^\s+description: (.+)$') {
                $description = $matches[1]
                $i++
            }

            # rule: >- の部分を処理
            if ($i -lt $Lines.Count -and $Lines[$i] -match '^\s+rule: >-$') {
                $i++ # rule: >- の次の行から開始

                # rule の内容を収集
                $ruleLines = @()
                $baseIndent = $null

                while ($i -lt $Lines.Count) {
                    $line = $Lines[$i]

                    # 空行はそのまま追加
                    if ($line.Trim() -eq '') {
                        $ruleLines += ''
                        $i++
                        continue
                    }

                    # rule内容のインデントレベルを確認
                    if ($line -match '^(\s+)(.*)$') {
                        $indent = $matches[1]
                        $content = $matches[2]

                        # 基準インデントを設定（最初の非空行から）
                        if ($null -eq $baseIndent) {
                            $baseIndent = $indent
                        }

                        # 基準インデント以上の場合はrule内容として処理
                        if ($indent.Length -ge $baseIndent.Length -and $line.StartsWith($baseIndent)) {
                            # 基準インデントを削除
                            $processedLine = $line.Substring($baseIndent.Length)
                            $ruleLines += $processedLine
                            $i++
                        } else {
                            # インデントが基準より少ない場合は終了
                            break
                        }
                    } else {
                        # インデントがない行は終了
                        break
                    }
                }

                # rule内容をMarkdownに変換
                if ($ruleLines.Count -gt 0) {
                    $ruleContent = Convert-RuleContentToMarkdown $ruleLines
                }
            }

            # Markdownとして結合
            if ($ruleContent -ne "") {
                $result += $ruleContent
            }

            # $i は既に次の行を指しているので、そのまま継続
            continue
        }
        else {
            # その他の行（空行など）
            $result += $line
            $i++
        }
    }

    return $result
}

function Convert-RuleContentToMarkdown {
    param([string[]]$RuleLines)

    if ($RuleLines.Count -eq 0) {
        return ""
    }

    $result = @()

    foreach ($line in $RuleLines) {
        if ($line.Trim() -eq '') {
            $result += ''
            continue
        }

        # 通常の内容処理
        $processedLine = $line

        # Markdown 見出しを 2 段階下げる
        if ($line -match '^\s*(#{1,4})\s+(.*)$') {
            $hashCount = $matches[1].Length
            $titleText = $matches[2]
            $newHashCount = $hashCount + 2
            $processedLine = "#" * $newHashCount + " " + $titleText
        } else {
            # 見出し以外の行：そのまま使用（既にインデントは削除済み）
            $processedLine = $line
        }

        $result += $processedLine
    }

    return $result -join "`n"
}

function Extract-RulesFromContinueConfig {
    param([string]$ConfigPath)
    
    try {
        $content = Get-Content $ConfigPath -Raw -Encoding UTF8
        
        # rules: から次のトップレベル要素までを抽出 (先頭に空白のない行で終了)
        if ($content -match '(?sm)^rules:\r?\n(.*?)(?=^[a-zA-Z_]+:|\z)') {
            $rulesContent = $matches[1]
            
            # 各行から先頭の2文字分のインデントを削除 (YAML の rules: 以下の内容)
            $rulesLines = $rulesContent -split '\r?\n'
            $processedLines = @()
            
            foreach ($line in $rulesLines) {
                if ($line -match '^  (.*)$') {
                    # 先頭2文字のスペースを削除
                    $processedLines += $matches[1]
                } elseif ($line.Trim() -eq '') {
                    # 空行はそのまま保持
                    $processedLines += ''
                } else {
                    # インデントがない行は終了の合図
                    break
                }
            }
            
            # 末尾の空行を削除
            while ($processedLines.Count -gt 0 -and $processedLines[-1].Trim() -eq '') {
                $processedLines = $processedLines[0..($processedLines.Count - 2)]
            }
            
            
            # YAML複数行表現をMarkdownに変換
            $markdownLines = Convert-YamlToMarkdown $processedLines
            
            return $markdownLines -join "`n"
        } else {
            throw "Rules section not found"
        }
    }
    catch {
        Write-Host "Error: Failed to parse config.yaml: $($_.Exception.Message)"
        return $null
    }
}

function Update-ClaudeConfig {
    param(
        [string]$ConfigPath,
        [string]$NewRulesContent
    )
    
    try {
        $content = Get-Content $ConfigPath -Raw -Encoding UTF8
        
        # ## important_rules セクションの開始位置を見つける
        if ($content -match '(?sm)^## important_rules\r?\n') {
            # 常に1つの空行を追加
            $replacement = "## important_rules`n`n$NewRulesContent`n"
            
            $newContent = $content -replace '(?sm)^(## important_rules\r?\n).*?(?=^## (?!#)|\z)', $replacement
            
            # UTF-8 (BOM なし) で保存
            [System.IO.File]::WriteAllText($ConfigPath, $newContent, $Utf8NoBomEncoding)
            return $true
        } else {
            Write-Host "Error: ## important_rules section not found"
            return $false
        }
    }
    catch {
        Write-Host "Error: Failed to update CLAUDE.md: $($_.Exception.Message)"
        return $false
    }
}

# メイン処理
Write-Host "=== Continue Config Rules Sync Script ==="
Write-Host "Continue Config: $ContinueConfigPath"
Write-Host "Claude Config: $ClaudeConfigPath"
Write-Host ""

# ファイル存在確認
if (-not (Test-FileExists $ContinueConfigPath) -or -not (Test-FileExists $ClaudeConfigPath)) {
    exit 1
}

# rules セクションを抽出
Write-Host "Extracting rules section from Continue Config..."
$rulesContent = Extract-RulesFromContinueConfig $ContinueConfigPath

if ($null -eq $rulesContent) {
    Write-Host "Process aborted"
    exit 1
}

Write-Host "Extraction completed ($($rulesContent.Split("`n").Count) lines)"

# デバッグファイルのクリーンアップ
$debugFiles = @("debug-extracted-rules.txt", "debug-raw-rules.txt")
foreach ($file in $debugFiles) {
    if (Test-Path $file) {
        Remove-Item $file -Force
    }
}

# Claude Config を更新
Write-Host "Updating ## important_rules section in Claude Config..."
$success = Update-ClaudeConfig $ClaudeConfigPath $rulesContent

if ($success) {
    Write-Host "Sync completed successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Updated file:"
    Write-Host "  $ClaudeConfigPath"
} else {
    Write-Host "Sync failed" -ForegroundColor Yellow
    exit 1
}