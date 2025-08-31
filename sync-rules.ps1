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

function Write-Message {
    param(
        [string]$Message
    )
    Write-Host $Message
}

function Test-FileExists {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Message "Error: File not found: $FilePath"
        return $false
    }
    return $true
}

function Convert-YamlToMarkdown {
    param([string[]]$Lines)
    
    $result = @()
    
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        
        if ($line -eq '- >-') {
            # 複数行ブロック開始 - 内容を収集
            $blockLines = @()
            $i++ # >- の次の行から開始
            
            # ブロック内容を収集
            while ($i -lt $Lines.Count -and -not ($Lines[$i] -match '^- ')) {
                $blockLines += $Lines[$i]
                $i++
            }
            
            # ブロック内容をMarkdownに変換
            if ($blockLines.Count -gt 0) {
                $markdownBlock = Convert-MultilineBlockToMarkdown $blockLines
                $result += $markdownBlock
            }
            
            # $i は次の '- ' 行を指しているので、1つ戻す
            $i--
        }
        elseif ($line -match '^- ') {
            # 通常のリスト項目
            $result += $line
        }
        else {
            # その他の行（空行など）
            $result += $line
        }
    }
    
    return $result
}

function Convert-MultilineBlockToMarkdown {
    param([string[]]$BlockLines)
    
    if ($BlockLines.Count -eq 0) {
        return @()
    }
    
    $result = @()
    $foundTitle = $false
    
    foreach ($line in $BlockLines) {
        if ($line.Trim() -eq '') {
            $result += ''
            continue
        }
        
        # 最初の **タイトル** を見つけてサブ見出しに変換
        if (!$foundTitle -and $line -match '\*\*(.+?)\*\*') {
            $title = $matches[1]
            $foundTitle = $true
            
            # 前に空行を追加
            $result += ''           # 前の空行
            $result += "### $title" # サブ見出し
            
            # タイトル行の残りの部分があれば追加
            $remainingText = $line -replace '\*\*(.+?)\*\*', ''
            if ($remainingText.Trim() -ne '') {
                $result += $remainingText.Trim()
            }
        } else {
            # 通常の内容 - サブ見出し以降はさらに2文字分のインデントを削除
            if ($foundTitle -and $line -match '^  (.*)$') {
                $result += $matches[1]
            } else {
                $result += $line
            }
        }
    }
    
    return $result
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
        Write-Message "Error: Failed to parse config.yaml: $($_.Exception.Message)"
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
            Write-Message "Error: ## important_rules section not found"
            return $false
        }
    }
    catch {
        Write-Message "Error: Failed to update CLAUDE.md: $($_.Exception.Message)"
        return $false
    }
}

# メイン処理
Write-Message "=== Continue Config Rules Sync Tool ==="
Write-Message "Continue Config: $ContinueConfigPath"
Write-Message "Claude Config: $ClaudeConfigPath"
Write-Message ""

# ファイル存在確認
if (-not (Test-FileExists $ContinueConfigPath) -or -not (Test-FileExists $ClaudeConfigPath)) {
    exit 1
}

# rules セクションを抽出
Write-Message "Extracting rules section from Continue Config..."
$rulesContent = Extract-RulesFromContinueConfig $ContinueConfigPath

if ($null -eq $rulesContent) {
    Write-Message "Process aborted"
    exit 1
}

Write-Message "Extraction completed ($($rulesContent.Split("`n").Count) lines)"

# デバッグファイルのクリーンアップ
$debugFiles = @("debug-extracted-rules.txt", "debug-raw-rules.txt")
foreach ($file in $debugFiles) {
    if (Test-Path $file) {
        Remove-Item $file -Force
    }
}

# Claude Config を更新
Write-Message "Updating ## important_rules section in Claude Config..."
$success = Update-ClaudeConfig $ClaudeConfigPath $rulesContent

if ($success) {
    Write-Message "Sync completed successfully"
    Write-Message ""
    Write-Message "Updated file:"
    Write-Message "  $ClaudeConfigPath"
} else {
    Write-Message "Sync failed"
    exit 1
}