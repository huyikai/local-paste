# LocalPaste 🗂️

[![CI](https://github.com/huyikai/local-paste/actions/workflows/release.yml/badge.svg)](https://github.com/huyikai/local-paste/actions/workflows/release.yml)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-orange)](https://github.com/huyikai/local-paste)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

日本語 | [English](README.md) | [中文](README_zh.md)

macOS 用の軽量クリップボード履歴マネージャー。完全ローカル動作。

すべてのデータはあなたのマシンに保存されます。サブスクリプション不要、クラウド不要、App Store 不要。

## 機能

- **全ペーストボードタイプに対応** — テキスト、リッチテキスト (RTF/RTFD)、HTML、画像、PDF、ファイルパス、カラー
- **メニューバー常駐** — アイコンをクリック、または `⌥⌘V` でフローティングパネルを表示
- **キーボード操作** — `↑↓` で移動、`Enter` で貼り付け、`Space` でプレビュー、`Esc` で閉じる
- **入力即検索** — 検索ボックスをクリックせずに、そのまま入力して絞り込み
- **リッチプレビュー** — HTML/RTF の書式を履歴リストとプレビューパネルで表示
- **グループでブックマーク** — 右クリックまたはブックマークアイコンでアイテムをカスタムグループに保存
- **プレーンテキスト貼り付け** — `⌘⇧V` または右クリックメニュー
- **カラースウォッチ表示** — 16進カラー値を自動検出し、背景色で表示。Space で全画面カラースウォッチ
- **永続保存** — `~/Library/Application Support/LocalPaste/` に JSON ファイルで保存
- **設定可能な上限** — 50〜2000 件の履歴、ログイン時起動に対応
- **100% オフライン** — インターネット不要、データ収集なし、アカウント不要

## 動作環境

- macOS 13.0 (Ventura) 以降
- Apple Silicon または Intel Mac

## インストール

### Homebrew（推奨）

```bash
brew tap huyikai/local-paste
brew install --cask localpaste
```

#### アップデート

```bash
brew update
brew upgrade --cask localpaste
```

#### アンインストール

```bash
brew uninstall --cask localpaste
brew untap huyikai/local-paste
```

### 手動ダウンロード

[最新リリース](https://github.com/huyikai/local-paste/releases/latest) から `LocalPaste.dmg` をダウンロードし、開いて **LocalPaste** を **アプリケーション** にドラッグ。

> 「開発元が未確認」と表示された場合は、アプリを右クリック → **開く** で回避できます。

## 使い方

| 操作 | ショートカット |
|---|---|
| パネルを開く / 閉じる | メニューバーアイコンをクリック、または `⌥⌘V` |
| 項目を移動 | `↑` `↓` |
| 選択項目を貼り付け | `Enter` |
| プレビュー | `Space`（トグル） |
| 履歴を検索 | 任意の文字を入力 |
| 検索モードを終了 | `Esc` |
| パネルを閉じる | `Esc` またはパネル外をクリック |
| ブックマーク / 解除 | ブックマークボタンまたは右クリック |
| 書式なしで貼り付け | `⌘⇧V` または右クリック |

### 自動貼り付け（Enter 後に ⌘V）

`Enter` でクリップボードにコピーされます。アクティブなアプリに自動貼り付けするには：

1. 任意の項目で `Enter` を押す → プロンプトに従う
2. **システム設定 → プライバシーとセキュリティ → アクセシビリティ** で **LocalPaste** を有効にする
3. LocalPaste を再起動

## LocalPaste を選ぶ理由

| | LocalPaste | クラウド型競合 |
|---|---|---|
| インターネット必須 | ❌ 不要 | ✅ しばしば必要 |
| アカウント必須 | ❌ 不要 | ✅ ほぼ必須 |
| データはローカル | ✅ はい | ❌ クラウド上 |
| サブスクリプション | ❌ 永久無料 | 💰 月額課金 |
| オープンソース | ✅ MIT | ❌ ほぼクローズド |
| リソース使用量 | ~30 MB メモリ | 100–500 MB (Electron) |

## ソースからビルド

```bash
make build           # 現在のアーキテクチャでリリースビルド
make build-universal # ユニバーサルバイナリ (arm64 + x86_64)
make app             # .app バンドルを生成
make dmg             # .app → DMG インストーラー
make install         # .app → /Applications
make run             # コマンドラインから実行
```

## リリース

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions が自動的にユニバーサル DMG をビルドし、リリースを作成します。Homebrew cask は常に最新リリースを指すため、ユーザーは `brew upgrade --cask localpaste` のみで更新できます。

## FAQ

<details>
<summary><strong>「開発元が未確認」と表示される？</strong></summary>

このアプリは ad-hoc 署名（Apple 公証なし）のためです。
Finder でアプリを右クリック → <strong>開く</strong> で実行するか、以下を実行：

<pre>sudo xattr -d com.apple.quarantine /Applications/LocalPaste.app</pre>
</details>

<details>
<summary><strong>自動貼り付けが機能しない？</strong></summary>

<strong>システム設定 → プライバシーとセキュリティ → アクセシビリティ</strong> で<br>
LocalPaste が有効になっているか確認してください。<br>
許可後はアプリを再起動してください。
</details>

<details>
<summary><strong>データはどこに保存される？</strong></summary>

<code>~/Library/Application Support/LocalPaste/</code> — 1つの JSON ファイルです。
バックアップ、削除して履歴をリセット、またはクラウドフォルダにシンボリックリンクできます。
</details>

## ライセンス

[MIT](LICENSE)
