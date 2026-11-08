<div align="center">

<img src="docs/images/icon.png?v=0.2.6" width="112" alt="Claude Switch アイコン">

# Claude Switch

**アカウントを切り替えて、作業の続きを。**

Claude Desktop のアカウントと残りの使用量を、Mac のメニューバーに。切り替えるときは、続けたい Code セッションも一緒に。

[![最新リリース](https://img.shields.io/badge/Download-latest_release-C9653F?style=flat-square)](https://github.com/torpedo2003/claude-desktop-switch/releases/latest)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111?style=flat-square&logo=apple)
[![License: MIT](https://img.shields.io/badge/license-MIT-3B82F6?style=flat-square)](LICENSE)

[English](README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · **日本語**

[インストール](#インストール) · [はじめかた](#はじめかた) · [切り替え時の動作](#切り替え時の動作) · [別の Mac へ移行](#別の-mac-へ移行) · [よくある質問](#よくある質問)

<br>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/hero-ja-dark.jpg?v=0.2.6">
  <img src="docs/images/hero-ja-light.jpg?v=0.2.6" alt="Claude Switch：アカウントウインドウとメニューバーのパネル">
</picture>

</div>

## Claude Switch とは

個人用と仕事用のアカウントを使い分けるたびに、ログインし直したり、残りの使用量を確認したり、会話を探し直したり。Claude Switch はよく使うアカウントをまとめ、余裕のあるアカウントでローカルの Code セッションを続けられるようにします。

## 主な機能

- **再ログインせずに切り替え**：いつものアカウントを一度保存すれば、あとはメニューバーから選ぶだけ。
- **残りの使用量をまとめて確認**：アカウントを切り替えずに、それぞれの余裕を見比べられます。
- **残りが少なくなったらお知らせ**：余裕のある別のアカウントがあれば、切り替えを検討できるように知らせます。
- **作業をまとめて引き継ぐ**：Code の会話、サブタスク、添付ファイルを別のアカウントへ。保存されたパネルやファイル表示も引き継げます。
- **追加しても、元のログインはそのまま**：新しいアカウントも保存して、必要なときに元のアカウントへ戻れます。
- **自分の使い方を振り返る**：ローカルの Code の日別使用量、よく使うモデル、活動の傾向を確認できます。
- **別の Mac へ移行**：アカウント、保存したログイン、設定をパスワード付きファイルに書き出し、新しい Mac で読み込めます。

## スクリーンショット

**会話の続きを別のアカウントで。**

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/conversations-ja-dark.png?v=0.2.6">
  <img src="docs/images/conversations-ja-light.png?v=0.2.6" alt="会話の続きを別のアカウントで。">
</picture>

**引き継ぐ会話を、その場で選ぶ。**

切り替えの確認画面で会話を選べます。最近使った会話はあらかじめ選択され、確定した選択は次回にも引き継がれます。

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/switch-selection-ja-dark.png?v=0.2.6">
  <img src="docs/images/switch-selection-ja-light.png?v=0.2.6" width="720" alt="引き継ぐ会話を、その場で選ぶ。">
</picture>

<table>
  <tr>
    <td width="33%" valign="top">
      <p><b>残りが少なくなったらお知らせ。</b></p>
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="docs/images/switch-reminder-menu-ja-dark.png?v=0.2.6">
        <img src="docs/images/switch-reminder-menu-ja-light.png?v=0.2.6" alt="残りが少なくなったらお知らせ。">
      </picture>
    </td>
    <td width="67%" valign="top">
      <p><b>自分の使い方を振り返る。</b></p>
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="docs/images/usage-ja-dark.png?v=0.2.6">
        <img src="docs/images/usage-ja-light.png?v=0.2.6" alt="自分の使い方を振り返る。">
      </picture>
    </td>
  </tr>
</table>

<sub>スクリーンショットには架空のサンプルデータを使用しています。</sub>

## インストール

**動作環境**：macOS 14 Sonoma 以降（Apple シリコン／Intel）、[Claude Desktop](https://claude.ai/download) がインストール済みであること。

1. [最新リリース](https://github.com/torpedo2003/claude-desktop-switch/releases/latest) から `ClaudeSwitch-<バージョン>-macOS.zip` をダウンロードします。
2. 解凍して **Claude Switch** を「アプリケーション」フォルダに移動します。
3. 起動します。まだ Apple の公証を受けていないため、初回のみ次の操作が必要です。
   - macOS 15 以降：**システム設定 → プライバシーとセキュリティ** を開き、下にスクロールして **このまま開く** をクリックします。
   - macOS 14：アプリを右クリックして **開く** を選び、確認します。

   ターミナルでダウンロード時の隔離属性を外すこともできます。

   ```sh
   xattr -dr com.apple.quarantine "/Applications/Claude Switch.app"
   ```

各リリースのダウンロードには SHA-256 チェックサムを添えています。

### アップデート

**設定 → アップデート** で新しいバージョンを確認したり、自動確認を無効にしたりできます。**最新バージョンを見る** から [ダウンロードページ](https://github.com/torpedo2003/claude-desktop-switch/releases/latest) を開き、手動でインストールしてください。

「アプリケーション」内の旧版を置き換える前に Claude Switch を終了します。起動時に許可を求められたら **アクセスを許可** を選び、macOS のダイアログで確認してください。**常に許可** を選ぶと、繰り返しの確認を減らせます。

## はじめかた

1. いつもどおり **Claude Desktop にサインイン** してから Claude Switch を開き、求められたらキーチェーンへのアクセスを許可します。そのアカウントが自動で保存されます。
2. メニューバーの **アカウントを追加…** をクリックします。Claude がサインイン画面で再起動するので、別のアカウントでサインインすると、そちらも自動で保存されます。
3. メニューバーやアカウントウインドウから **切り替え** を選び、引き継ぐ Code の会話を選択して確定します。

会話履歴と保存された表示状態を引き継ぎます。実行中のタスクは切り替え前に終了し、切り替え後に Claude で再開してください。

初回設定または **設定 → 通知** で、切り替えのおすすめと操作結果の通知を有効にできます。切り替えには毎回確認が必要です。

> [!IMPORTANT]
> アカウントの切り替えには Claude Switch を使い、Claude の **ログアウト** や Claude Code の `/login` は使わないでください。
> サインアウトすると Anthropic 側でそのログインが無効になり、Claude Switch が保存したコピーも使えなくなります。
> Claude がログインを復元できない場合は、もう一度サインインすれば再び保存されます。

メインウインドウのショートカット：`⌘1` `⌘2` `⌘3` でページ切り替え、`⌘K` でアカウントと会話を検索、`⌘R` でローカルのアカウントと会話を更新。使用量は各アカウントの更新ボタンから取得できます。

## 切り替え時の動作

1. Claude Switch が、選んだアカウントの保存済みログインを確認します。
2. Claude を通常どおり終了し、現在のアカウントを保存します。実行中の作業は中断されるので、先に終わらせてください。Claude が終了しない場合、切り替えは中止されます。
3. 選んだアカウントのログインに置き換え、選択した Code の会話をそのアカウントへ移します。
4. 選んだアカウントでサインインした状態の Claude が開きます。

途中で失敗した場合は、Claude の元のファイルを復元し、元の状態で Claude を開き直します。

| 変わるもの | 変わらないもの |
| --- | --- |
| Claude Desktop のログイン | Claude Code CLI のログイン |
| 選択した Code の会話が属するアカウント | プロジェクトとそのファイル |
| | MCP の設定、スキル、プラグイン、フック |
| | Cowork の会話（アカウント間で移せません） |

## 別の Mac へ移行

両方の Mac に Claude Switch 0.2.8 以降が必要です。新しい Mac では、Claude Desktop をインストールして一度開いてから Claude Switch を開いてください。

1. 古い Mac で **設定 → 別の Mac へ移行 → アカウントを書き出す…** を開き、12 文字以上のパスワードを設定してファイルを保存します。
2. AirDrop や USB ドライブなどで、ファイルを新しい Mac へ移します。
3. 新しい Mac で **設定 → 別の Mac へ移行 → アカウントを読み込む…** を開き、同じパスワードを入力してファイルを選びます。

ファイルにはアカウント、保存したログイン、クォータの履歴、フォロー設定、環境設定が含まれます。Code の会話は含まれません。会話は `~/.claude` と Claude Desktop 自身のフォルダにあります。

- ファイルとパスワードがあれば誰でもこれらのアカウントにサインインできるので、使い終わったらファイルを削除してください。パスワードを忘れると復旧できません。
- 新しい Mac に保存済みのログインはそのまま残ります。変換できないアカウントはスキップされ、結果に件数が表示されます。
- 移行後は 2 台の Mac が同じログインを持つため、片方でトークンが更新されるともう片方がサインアウトされることがあります。読み込んだログインを Claude が受け付けない場合は、新しい Mac でそのアカウントに一度サインインすると保存し直されます。

## プライバシーとセキュリティ

- 保存したログインは Mac 上で暗号化し、ログインキーチェーンで保護します。
- テレメトリ、追跡、独自サーバーはありません。ローカルの会話もアップロードしません。
- 使用上限の確認は Anthropic、バージョン確認は GitHub に接続します。どちらの自動確認も無効にできます。
- 中断した切り替えは設定から復元できます。プロジェクトや Claude Code CLI のログインは変更しません。

詳細（英語）：[仕組み](docs/how-it-works.md) · [使用上限と統計](docs/usage-data.md) · [セキュリティポリシー](.github/SECURITY.md)

## よくある質問

<details>
<summary><b>macOS が「Claude Safe Storage」の使用許可を求めてくるのはなぜですか？</b></summary>

アカウントの使用上限を表示するために、この許可が必要です。保存したログインの保護には別の許可を使います。**アクセスを許可** を選んで macOS のダイアログを確認してください。**常に許可** を選ぶと、繰り返しの確認を減らせます。
</details>

<details>
<summary><b>Claude Code の CLI も切り替わりますか？</b></summary>

いいえ。Claude Switch が切り替えるのは Claude Desktop です。Claude Code のコマンドラインツールは独自のログインを持ち続けます。
</details>

<details>
<summary><b>「—」や古い数値が表示されるアカウントがあるのはなぜですか？</b></summary>

「—」は使用上限をまだ取得できていない状態です。更新できない場合はそのアカウントに切り替え、Claude にサインインしていることを確認してから再度更新してください。
</details>

<details>
<summary><b>保存したアカウントを別の Mac に移せますか？</b></summary>

はい。[別の Mac へ移行](#別の-mac-へ移行)をご覧ください。データフォルダを手動でコピーしても使えません。解除に必要なキーが古い Mac に残るためです。
</details>

<details>
<summary><b>起動時に「保存したログインの暗号化キーが見つかりません」で止まる</b></summary>

データフォルダに保存済みログインがありますが、この Mac のキーチェーンにそれを解除するキーがありません。多くの場合、フォルダを別の Mac からコピーしたことが原因です。**アクセスを許可** では解決できず、このデータはこの Mac では読み取れません。

1. Claude Switch を終了します。
2. Finder で `~/Library/Application Support/Claude Desktop Switch` の名前を変更して残します（例：`Claude Desktop Switch old`）。
3. Claude Switch を開き、**アクセスを許可** を選びます。
4. [別の Mac へ移行](#別の-mac-へ移行)の手順でアカウントを移します。完了後は名前を変更したフォルダを削除できます。
</details>

<details>
<summary><b>Claude Desktop のアップデートで動かなくなりませんか？</b></summary>

Claude Desktop の更新に合わせて、Claude Switch の更新が必要になる場合があります。切り替えが動かなくなったら新しいリリースを確認するか、[Issue を報告](https://github.com/torpedo2003/claude-desktop-switch/issues/new/choose)してください。
</details>

## ソースからビルド

Xcode 16 以降（Swift 6 ツールチェーン）が必要です。

```sh
git clone https://github.com/torpedo2003/claude-desktop-switch.git
cd claude-desktop-switch
swift test                               # ユニットテスト
zsh scripts/build.sh                     # "dist/Claude Switch.app" を作成
open "dist/Claude Switch.app" --args --demo   # サンプルデータで試す
```

`scripts/build.sh --read-only` を使うと、表示はすべてできるものの Claude のファイルを決して変更しないバージョンをビルドできます。詳しくは [アーキテクチャ](docs/architecture.md) と [コントリビューションガイド](.github/CONTRIBUTING.md)（英語）をご覧ください。

## 表示言語

English、简体中文、繁體中文、日本語、한국어、Español、Français、Deutsch、Português (Brasil)、Русский。macOS の言語に従い、設定から変更することもできます。翻訳の改善も歓迎します。

## コントリビューション

バグ報告、アイデア、プルリクエストを歓迎します。まず [コントリビューションガイド](.github/CONTRIBUTING.md) をお読みください。セキュリティ上の問題は [セキュリティポリシー](.github/SECURITY.md) に従って非公開で報告してください。

Claude Code などの AI コーディングアシスタントを使う場合は、[AGENTS.md](AGENTS.md) と [CLAUDE.md](CLAUDE.md) にプロジェクトのルール、コマンド、スラッシュコマンドをまとめています。このアプリが依存する Claude Desktop と Claude Code のローカルデータ形式は [docs/claude-internals.md](docs/claude-internals.md)（英語）にあります。

## ライセンス

[MIT](LICENSE)

Claude Switch は独立したオープンソースプロジェクトであり、Anthropic とは提携・推奨・後援の関係にありません。Claude および Claude Desktop は Anthropic, PBC の商標です。利用が認められたアカウントでのみ、Anthropic の規約に従ってご利用ください。
