param(
    [Parameter(Mandatory = $true)][string]$InputFile,
    [Parameter()][int]$StartRow = 1,
    [Parameter()][int]$MaxRows = 0,
    [Parameter()][string]$Separator = ",",
    [Parameter()][string]$Encoding = "Shift_JIS",
    [Parameter()][int[]]$TargetColumns = @(),
    [Parameter()][ValidateSet("exclude", "include")]
    [string]$Mode = "exclude"
)

# 実行履歴をスクリプトのカレントフォルダに追記（タイムスタンプ付き）
try {
    $scriptPath = $MyInvocation.MyCommand.Path
    $scriptDir = [System.IO.Path]::GetDirectoryName($scriptPath)
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
    #Write-Host "scriptName: $scriptName.history "
    $logFile = Join-Path $scriptDir "$scriptName.history"

    $invocationLine = ".\" + [System.IO.Path]::GetFileName($scriptPath) + " " + ($MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object {
        $key = $_.Key
        $value = if ($_.Value -is [Array]) {
            $_.Value -join ','
        } else {
            $_.Value
        }

        if ($value -is [string] -and $value.Contains(' ')) {
            "-$key `"$value`""
        } else {
            "-$key $value"
        }
    }) -join ' '

    $timestamp = Get-Date -Format "[yyyy-MM-dd HH:mm:ss]"
    Add-Content -Path $logFile -Value "$timestamp $invocationLine"
} catch {
    Write-Warning "ログファイルへの書き込みに失敗しました: $_"
}

# 区切り文字の正規化
# Powershellでは「タブ」を `t で表記するため
switch ($Separator) {
    '\t' { $Separator = "`t" }
    '\\t' { $Separator = "`t" }
}

$escapedSeparator = [Regex]::Escape($Separator)
$splitPattern = "$escapedSeparator(?=(?:[^""]*""[^""]*"")*[^""]*$)"

function SplitCsvLine {
    param([string]$line)
    return [regex]::Split($line, $splitPattern)
}

function DetectNewLine {
    param([byte[]]$bytes)

    for ($i = 0; $i -lt $bytes.Length - 1; $i++) {
        if ($bytes[$i] -eq 0x0D -and $bytes[$i + 1] -eq 0x0A) {
            return "`r`n"  # CRLF
        }
        elseif ($bytes[$i] -eq 0x0A) {
            return "`n"    # LF
        }
    }
    return "`n"  # デフォルトは LF
}

# ファイル存在チェック
if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

# 出力ファイルパス生成
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$folderPath = [System.IO.Path]::GetDirectoryName($InputFile)
$inputExtension = [System.IO.Path]::GetExtension($InputFile)
$OutputFile = [System.IO.Path]::Combine($folderPath, "${baseName}_${Mode}${inputExtension}")

# BOM判定と改行コード検出（先頭数KBのみ読み込み）
$fs = [System.IO.FileStream]::new($InputFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
$buffer = New-Object byte[] 4096
#$bytesRead = $fs.Read($buffer, 0, $buffer.Length)
$fs.Close()

$hasBOM = ($buffer.Length -ge 3 -and $buffer[0] -eq 0xEF -and $buffer[1] -eq 0xBB -and $buffer[2] -eq 0xBF)
$newLineChar = DetectNewLine -bytes $buffer

# エンコーディングオブジェクト生成
$encodingObj = if ($Encoding -eq "UTF-8") {
    New-Object System.Text.UTF8Encoding($true)
} else {
    [System.Text.Encoding]::GetEncoding($Encoding)
}

# リーダー取得（逐次読み込み）
try {
    $reader = [System.IO.StreamReader]::new($InputFile, $encodingObj)
} catch [System.IO.FileNotFoundException] {
    Write-Error "ファイルが見つかりません: $InputFile"
}
catch [System.UnauthorizedAccessException] {
    Write-Error "ファイルにアクセスできません。権限を確認してください。"
}
catch {
    Write-Error "その他のエラー: $_.Exception.Message"
}



# ライター取得（改行コードを明示）
$writerEncoding = if ($Encoding -eq "UTF-8") {
    if ($hasBOM) {
        [System.Text.Encoding]::UTF8
    } else {
        New-Object System.Text.UTF8Encoding($false)
    }
} else {
    [System.Text.Encoding]::GetEncoding($Encoding)
}
$writer = [System.IO.StreamWriter]::new($OutputFile, $false, $writerEncoding)
$writer.NewLine = $newLineChar

# 対象カラム（0始まりに変換）
$targetIndexes = $TargetColumns | ForEach-Object { $_ - 1 }

# 行処理開始
$currentLineNumber = 0
$linesWritten = 0
$maxToRead = if ($MaxRows -gt 0) { $MaxRows } else { [int]::MaxValue }
$ProgressInterval = 10000

while (-not $reader.EndOfStream) {
    $line = $reader.ReadLine()
    $currentLineNumber++

    if ($currentLineNumber -lt $StartRow) {
        continue
    }

    if ($linesWritten -ge $maxToRead) {
        break
    }

    #$columns = SplitCsvLine -line $line -Separator $Separator
    $columns = SplitCsvLine -line $line

    $filtered = for ($i = 0; $i -lt $columns.Count; $i++) {
        $isTarget = $targetIndexes -contains $i

        if ($Mode -eq "exclude" -and -not $isTarget) {
            $columns[$i]
        }
        elseif ($Mode -eq "include" -and $isTarget) {
            $columns[$i]
        }
    }

    $csvLine = $filtered -join $Separator
    $writer.WriteLine($csvLine)
    
    if ($linesWritten -ge $ProgressInterval -and $linesWritten % $ProgressInterval -eq 0) {
        Write-Host "$linesWritten 行処理済み..."
    }

    $linesWritten++
}

$reader.Close()
$writer.Close()

Write-Host "出力行数: $linesWritten"
Write-Host "${Mode} 処理後CSV出力完了: $OutputFile"
