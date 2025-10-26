# deploy.ps1

# .global\.claude\CLAUDE.md を、ユーザーのホームディレクトリ以下の .claude にコピー
# ただし、CLAUDE_CONFIG_DIR がある場合は優先

# .global\.continue\config.yaml を、ユーザーのホームディレクトリ以下の .continue にコピー
# ただし、CONTINUE_GLOBAL_DIR がある場合は優先

# エラー時に停止
$ErrorActionPreference = "Stop"

# スクリプトのディレクトリを取得
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ログ出力関数
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Color = switch ($Level) {
        "INFO" { "White" }
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor $Color
}

# ディレクトリ作成関数
function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Log "ディレクトリを作成しました: $Path"
    }
}

# ファイルコピー関数
function Copy-ConfigFile {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [string]$Description
    )

    if (-not (Test-Path -Path $SourcePath)) {
        Write-Log "ソースファイルが見つかりません。スキップします: $SourcePath" "INFO"
        return $null
    }

    # コピー先のファイルが存在しない場合はスキップ
    if (-not (Test-Path -Path $DestinationPath)) {
        Write-Log "コピー先のファイルが存在しません。スキップします: $DestinationPath" "INFO"
        return $null
    }

    try {
        $DestDir = Split-Path -Parent $DestinationPath
        Ensure-Directory -Path $DestDir

        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
        Write-Log "$Description をコピーしました" "INFO"
        Write-Log "  コピー元: $SourcePath" "INFO"
        Write-Log "  コピー先: $DestinationPath" "INFO"
        return $true
    }
    catch {
        Write-Log "$Description のコピーに失敗しました: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

Write-Log "デプロイを開始します"

# sync-rules.ps1 を実行してルールを同期
Write-Log "ルールの同期を開始します"
$SyncRulesPath = Join-Path $ScriptDir "sync-rules.ps1"

if (Test-Path -Path $SyncRulesPath) {
    try {
        $SyncResult = & $SyncRulesPath -ErrorAction Stop
        Write-Log "ルールの同期が完了しました" "INFO"
    }
    catch {
        Write-Log "ルールの同期に失敗しました: $($_.Exception.Message)" "WARN"
        Write-Log "デプロイを続行します" "INFO"
    }
}
else {
    Write-Log "sync-rules.ps1 が見つかりません。ルール同期をスキップします" "WARN"
}

# CLAUDE.md のデプロイ
$ClaudeSourcePath = Join-Path $ScriptDir "global\.claude\CLAUDE.md"

# CLAUDE_CONFIG_DIR 環境変数をチェック
$ClaudeConfigDir = $env:CLAUDE_CONFIG_DIR
if ($ClaudeConfigDir) {
    $ClaudeDestPath = Join-Path $ClaudeConfigDir "CLAUDE.md"
    Write-Log "CLAUDE_CONFIG_DIR 環境変数が設定されています: $ClaudeConfigDir"
}
else {
    $ClaudeDestPath = Join-Path $env:USERPROFILE ".claude\CLAUDE.md"
    Write-Log "デフォルトの Claude 設定ディレクトリを使用します: $(Split-Path $ClaudeDestPath)"
}

$ClaudeSuccess = Copy-ConfigFile -SourcePath $ClaudeSourcePath -DestinationPath $ClaudeDestPath -Description "CLAUDE.md"

# Continue config.yaml のデプロイ
$ContinueSourcePath = Join-Path $ScriptDir "global\.continue\config.yaml"

# CONTINUE_GLOBAL_DIR 環境変数をチェック
$ContinueGlobalDir = $env:CONTINUE_GLOBAL_DIR
if ($ContinueGlobalDir) {
    $ContinueDestPath = Join-Path $ContinueGlobalDir "config.yaml"
    Write-Log "CONTINUE_GLOBAL_DIR 環境変数が設定されています: $ContinueGlobalDir"
}
else {
    $ContinueDestPath = Join-Path $env:USERPROFILE ".continue\config.yaml"
    Write-Log "デフォルトの Continue 設定ディレクトリを使用します: $(Split-Path $ContinueDestPath)"
}

$ContinueSuccess = Copy-ConfigFile -SourcePath $ContinueSourcePath -DestinationPath $ContinueDestPath -Description "config.yaml"

# デプロイ結果の表示
Write-Log "=== デプロイ結果 ==="

$SuccessCount = 0
$SkipCount = 0
$FailCount = 0

# CLAUDE.md の結果
if ($ClaudeSuccess -eq $true) {
    Write-Log "CLAUDE.md のデプロイが完了しました" "INFO"
    $SuccessCount++
}
elseif ($ClaudeSuccess -eq $null) {
    Write-Log "CLAUDE.md のデプロイをスキップしました" "INFO"
    $SkipCount++
}
else {
    Write-Log "CLAUDE.md のデプロイに失敗しました" "ERROR"
    $FailCount++
}

# config.yaml の結果
if ($ContinueSuccess -eq $true) {
    Write-Log "config.yaml のデプロイが完了しました" "INFO"
    $SuccessCount++
}
elseif ($ContinueSuccess -eq $null) {
    Write-Log "config.yaml のデプロイをスキップしました" "INFO"
    $SkipCount++
}
else {
    Write-Log "config.yaml のデプロイに失敗しました" "ERROR"
    $FailCount++
}

# 総合結果
Write-Log "--- サマリ ---"
Write-Log "成功: $SuccessCount 件" "INFO"
if ($SkipCount -gt 0) {
    Write-Log "スキップ: $SkipCount 件" "INFO"
}
if ($FailCount -gt 0) {
    Write-Log "失敗: $FailCount 件" "ERROR"
}

if ($FailCount -gt 0) {
    Write-Log "一部のファイルでデプロイに失敗しました" "ERROR"
    exit 1
}
elseif ($SkipCount -gt 0) {
    Write-Log "一部のファイルがスキップされました" "INFO"
    exit 0
}
else {
    Write-Log "すべてのファイルが正常にデプロイされました" "INFO"
    exit 0
}
