# ps-csvColumnFilter

---

## 概要

`jp-csv-filter` は、日本語環境で扱うCSVファイルから、指定したカラムを抽出・除外できるPowerShellスクリプトです。  
Shift_JISやUTF-8（BOMあり／なし）に対応し、クォート構造を保持したまま出力します。

---

## 特徴

- ✅ Shift_JIS / UTF-8 対応（BOM有無判定付き）
- ✅ クォート構造を保持したままカラム抽出
- ✅ `include` / `exclude` モードで柔軟なフィルタリング
- ✅ `StartRow` や `MaxRows` による処理範囲指定
- ✅ 出力ファイル名自動生成（元ファイル名 + モード）

---
## オプション一覧（詳細）

| パラメータ        | 必須 | 型       | 説明 |
|-------------------|------|----------|------|
| `InputFile`       | ✅   | `string` | 入力CSVファイルのパス。Shift_JIS または UTF-8（BOMあり／なし）に対応。 |
| `StartRow`        | ❌   | `int`    | 処理開始行番号（1始まり）。デフォルトは `2`（ヘッダーをスキップ）。 |
| `MaxRows`         | ❌   | `int`    | 最大処理行数。`0` を指定すると全行を処理。 |
| `Separator`       | ❌   | `string` | 区切り文字。デフォルトは `,`。TSVの場合は `"`"`"`（タブ）を指定。 |
| `Encoding`        | ✅   | `string` | ファイルの文字コード。`Shift_JIS` または `UTF-8` を指定。BOMの有無は自動判定。 |
| `TargetColumns`   | ✅   | `int[]`  | 対象カラム番号（1始まり）。複数指定可能（例: `1,3,5`）。 |
| `Mode`            | ✅   | `string` | `"include"`：指定カラムのみ抽出、`"exclude"`：指定カラムを除外。 |

---

### 補足

- **カラム番号は1始まり**です（Excelと同じ感覚）。
- **`StartRow` を 1 にするとヘッダーも処理対象になります**。
- **出力ファイル名は自動生成**され、元ファイル名に `_include.csv` または `_exclude.csv` が付加されます。
- **Shift_JIS の場合は文字化け対策として明示的に指定するのが推奨**です。
- **UTF-8 の場合、BOMの有無は自動判定されます**。

---



## 必要環境

- PowerShell 7.x 以上（Windows）
- 日本語CSVファイル（Shift_JIS または UTF-8）

---

## 使い方

#### Shift_JISで書かれたcsvの1,3番目のカラムのみを取り出して以下ファイル名で出力する。
#### .\testdata\test_sjis_include.csv
```powershell
.\exclude_item_csv.ps1 `
    -InputFile ".\testdata\test_sjis.csv" `
	-StartRow 1 `
	-TargetColumns 1,3 `
	-Mode include
```
#### utf-8のcsvの3番目のカラムを除いた状態で以下ファイル名で出力する。
#### .\testdata\test_utf8_exclude.csv
```powershell
.\exclude_item_csv.ps1 `
	-InputFile ".\testdata\test_utf8.csv" `
	-StartRow 1 `
	-Encoding utf-8 `
	-TargetColumns 3 `
	-Mode exclude
```
#### Shift_JISで書かれたタブ区切りのファイルの場合
#### .\testdata\test_tab_sjis_include.csv
```powershell
.\exclude_item_csv.ps1 `
	-InputFile ".\testdata\test_tab_sjis.csv" `
	-StartRow 1 `
	-TargetColumns 1,2,3 `
	-Mode include `
	-Separator \t
```