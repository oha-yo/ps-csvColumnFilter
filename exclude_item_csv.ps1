param(
    [Parameter(Mandatory = $true)][string]$InputFile,
    [Parameter()][int]$StartRow = 2,
    [Parameter()][int]$MaxRows = 0,
    [Parameter()][string]$Separator = ",",
    [Parameter()][string]$Encoding = "Shift_JIS",
    [Parameter()][int[]]$TargetColumns = @(),
    [Parameter()][ValidateSet("exclude", "include")]
    [string]$Mode = "exclude"
)

function SplitCsvLine {
    param(
        [string]$line,
        [string]$Separator
    )
    # クォートを保持したまま分割
    $pattern = "$Separator(?=(?:[^""]*""[^""]*"")*[^""]*$)"
    return [regex]::Split($line, $pattern)
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

# UTF-8 BOM判定
$bytes = [System.IO.File]::ReadAllBytes($InputFile)
$hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

# リーダー取得
if ($Encoding -eq "UTF-8") {
    $bytesToUse = if ($hasBOM) { $bytes[3..($bytes.Length - 1)] } else { $bytes }
    $tempPath = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllBytes($tempPath, $bytesToUse)
    $reader = [System.IO.StreamReader]::new($tempPath, [System.Text.Encoding]::UTF8)
} else {
    $reader = [System.IO.StreamReader]::new($InputFile, [System.Text.Encoding]::GetEncoding($Encoding))
}

# 開始行までスキップ
$currentLineNumber = 0
while (-not $reader.EndOfStream -and $currentLineNumber -lt ($StartRow - 1)) {
    $reader.ReadLine() | Out-Null
    $currentLineNumber++
}

# 最大行数分の読み込み
$linesToProcess = [System.Collections.Generic.List[string]]::new()
$maxToRead = if ($MaxRows -gt 0) { $MaxRows } else { [int]::MaxValue }

while (-not $reader.EndOfStream -and $linesToProcess.Count -lt $maxToRead) {
    $linesToProcess.Add($reader.ReadLine())
}
$reader.Close()

# 対象カラム（0始まりに変換）
$targetIndexes = $TargetColumns | ForEach-Object { $_ - 1 }

# ライター取得
if ($Encoding -eq "UTF-8") {
    $utf8Encoding = if ($hasBOM) {
        [System.Text.Encoding]::UTF8
    } else {
        New-Object System.Text.UTF8Encoding($false)
    }
    $writer = [System.IO.StreamWriter]::new($OutputFile, $false, $utf8Encoding)
} else {
    $writer = [System.IO.StreamWriter]::new($OutputFile, $false, [System.Text.Encoding]::GetEncoding($Encoding))
}

foreach ($line in $linesToProcess) {
    $columns = SplitCsvLine -line $line -Separator $Separator

    $filtered = for ($i = 0; $i -lt $columns.Count; $i++) {
        $isTarget = $targetIndexes -contains $i

        if ($Mode -eq "exclude" -and -not $isTarget) {
            $columns[$i]
        }
        elseif ($Mode -eq "include" -and $isTarget) {
            $columns[$i]
        }
    }

    # クォート構造を保持したまま出力
    $csvLine = $filtered -join $Separator
    $writer.WriteLine($csvLine)
}
$writer.Close()

Write-Host "${Mode} 処理後CSV出力完了: $OutputFile"
