# dotfiles

macOSの開発環境設定を管理するリポジトリ。

## Managed files

- `.zshrc` - zshの設定
- `alfred/youtube/subtitles.rb` - YouTube再生リストの日本語自動字幕をZIPに保存するスクリプト

## YouTube字幕収集（Alfred）

Ruby、`yt-dlp`、`zip`、`unzip`が必要です。`yt-dlp`はHomebrewの標準的なインストール先（Apple Siliconでは`/opt/homebrew/bin`）から検索します。

### Alfred Workflowの設定

1. Alfred Preferencesで新しいWorkflowを作成します。
2. **Keyword**入力を追加し、再生リストURLを受け取る設定にします。
3. Keywordの出力を**Run Script**へ接続し、言語を`/bin/zsh`、入力方法を`with input as argv`に設定します。
4. Run Scriptに次の内容を設定します。

```zsh
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
exec "$HOME/.rbenv/shims/ruby" "$HOME/dotfiles/alfred/youtube/subtitles.rb" "$1"
```

5. AlfredでKeywordに続けてYouTube再生リストURLを入力して実行します。

### 出力と失敗の確認

- 動画本体はダウンロードせず、日本語の自動字幕（VTT）のみを取得します。
- ZIPは整合性を検証してから`~/Downloads`へ保存します。成功時は一時字幕ファイルを削除します。
- ZIPの作成または検証に失敗した場合は、元のVTTと失敗理由を`youtube-subtitles-zip-failed-日付時刻/`へ退避します。Downloadsへの退避にも失敗した場合は元ファイルの一時ディレクトリを削除せず、通知に場所を表示します。
- 取得できなかった動画がある場合は、動画タイトル・URL・理由を記録した`youtube-subtitles-日付時刻-failures.txt`も`~/Downloads`へ保存します。
- 処理結果はmacOSの通知にも表示されます。すべての動画で字幕が取得できなかった場合はZIPを作成せず、失敗一覧を保存します。
- 字幕とZIPはリポジトリ外に作成するため、Gitの管理対象にはなりません。
