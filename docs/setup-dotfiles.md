# dotfiles構築手順

## 目的

Macの開発環境設定をGitHubで管理し、設定変更の履歴を残せるようにする。

また、新しいMacへ移行した際に、同じ開発環境を再構築しやすくする。

## 1. GitHubにリポジトリを作成

GitHubで以下のリポジトリを作成する。

- Repository name: `dotfiles`
- README: 作成しない
- `.gitignore`: なし
- License: なし

今回はローカル側でREADMEやGitリポジトリを作成するため、GitHub側では空のリポジトリを作成した。

## 2. dotfilesディレクトリを作成

Railsアプリなどのプロジェクトとは独立して管理するため、ホームディレクトリ直下に `dotfiles` ディレクトリを作成する。

```bash
cd ~
mkdir dotfiles
cd dotfiles
```

現在地を確認する。

```bash
pwd
```

以下になっていればOK。

```text
/Users/kiruke/dotfiles
```

## 3. Gitリポジトリを作成

`dotfiles` ディレクトリをGitリポジトリにする。

```bash
git init
```

状態を確認する。

```bash
git status
```

今回は `main` ブランチを使用する。

## 4. 既存の.zshrcをバックアップ

現在使用している `.zshrc` を直接移動する前に、バックアップを作成する。

```bash
cp ~/.zshrc ~/.zshrc.backup
```

確認する。

```bash
ls -la ~/.zshrc*
```

以下の2ファイルが存在することを確認する。

```text
~/.zshrc
~/.zshrc.backup
```

## 5. .zshrcをdotfilesへ移動

`.zshrc` の本体を `dotfiles` リポジトリ内へ移動する。

```bash
mv ~/.zshrc ~/dotfiles/.zshrc
```

確認する。

```bash
ls -la ~/dotfiles
```

`.zshrc` が存在すればOK。

この時点では以下の状態になる。

```text
~/dotfiles/.zshrc    # 設定ファイル本体
~/.zshrc.backup      # 元の設定のバックアップ
```

## 6. シンボリックリンクを作成

zshは通常 `~/.zshrc` を読み込む。

しかし、今後は `~/dotfiles/.zshrc` をGit管理したいため、`~/.zshrc` からdotfiles内の `.zshrc` へシンボリックリンクを作成する。

```bash
ln -s ~/dotfiles/.zshrc ~/.zshrc
```

確認する。

```bash
ls -la ~/.zshrc
```

以下のように `->` が表示されれば成功。

```text
/Users/kiruke/.zshrc -> /Users/kiruke/dotfiles/.zshrc
```

構造としては以下になる。

```text
~/.zshrc
    ↓ symbolic link
~/dotfiles/.zshrc
    ↓
Gitで管理
```

## 7. zsh設定が正常に読み込めることを確認

```bash
source ~/.zshrc
```

エラーが発生しなければOK。

今後 `.zshrc` を変更するときは、実体である以下のファイルが変更される。

```text
~/dotfiles/.zshrc
```

その変更をGitで管理できる。

## 8. .zshrcをGitに登録

状態を確認する。

```bash
git status
```

`.zshrc` をステージングする。

```bash
git add .zshrc
```

commitする。

```bash
git commit -m "Add zsh configuration"
```

## 9. GitHubリポジトリと接続

GitHubで作成した `dotfiles` リポジトリをremoteとして登録する。

```bash
git remote add origin git@github.com:kiruke/dotfiles.git
```

確認する。

```bash
git remote -v
```

以下のように表示されればOK。

```text
origin  git@github.com:kiruke/dotfiles.git (fetch)
origin  git@github.com:kiruke/dotfiles.git (push)
```

## 10. GitHubへpush

最初のpushでは、ローカルの `main` とGitHubの `origin/main` を紐付ける。

```bash
git push -u origin main
```

以降は、

```bash
git push
```

だけでpushできる。

## 11. READMEを作成

dotfilesリポジトリの目的や利用方法を記録するため、READMEを作成する。

```bash
touch README.md
```

VS Codeで編集する場合は、

```bash
code README.md
```

READMEには、このリポジトリで管理している設定や、新しいMacで環境を復元する方法などを記載する。

## 12. Homebrewの環境をBrewfileに保存

`.zshrc` だけでは、`fzf` などHomebrewでインストールしたツールまでは復元できない。

そこで、Homebrewで管理しているツールを `Brewfile` に書き出す。

`~/dotfiles` で以下を実行する。

```bash
brew bundle dump --file=./Brewfile
```

内容を確認する。

```bash
cat Brewfile
```

今回の環境では、以下のようなものが記録された。

```ruby
brew "fzf"
brew "gh"
brew "macmon"
brew "rbenv"
```

さらにVS Code拡張機能やnpmのグローバルパッケージも記録された。

例:

```ruby
vscode "vscodevim.vim"
npm "@google/gemini-cli"
npm "yarn"
```

`brew bundle dump` は現在インストールされているものを広く取得するため、不要なツールや古いVS Code拡張機能が含まれていないか、後から整理する。

## 13. READMEとBrewfileをGit管理する

```bash
git add README.md Brewfile
```

状態を確認する。

```bash
git status
```

以下のようになっていることを確認する。

```text
Changes to be committed:
    new file: Brewfile
    new file: README.md
```

commitする。

```bash
git commit -m "Add README and Brewfile"
```

GitHubへ反映する。

```bash
git push
```

## 14. 構築手順をdocsに残す

dotfiles自体の構築方法もGitHubに残すため、`docs` ディレクトリを作成する。

```bash
mkdir -p docs
touch docs/setup-dotfiles.md
```

VS Codeで開く。

```bash
code docs/setup-dotfiles.md
```

今回の構築手順を `setup-dotfiles.md` に記録する。

## 現在の構成

最終的なリポジトリ構成は以下。

```text
dotfiles/
├── .git/
├── .zshrc
├── Brewfile
├── README.md
└── docs/
    └── setup-dotfiles.md
```

ホームディレクトリ側では、

```text
/Users/kiruke/
├── dotfiles/
│   └── .zshrc
│
├── .zshrc -> /Users/kiruke/dotfiles/.zshrc
└── .zshrc.backup
```

となっている。

## .zshrcで現在管理している主な設定

### Homebrew

HomebrewのPATH設定。

### rbenv

Rubyのバージョン管理。

### Rails / Bundler

```bash
alias be='bundle exec'
```

### Docker Compose

よく使うDocker Composeコマンドをalias化。

```bash
alias dcup="docker compose up -d"
alias dcdown="docker compose down"
alias dcexec="docker compose exec web"
alias dclog="docker compose logs -f"
alias dcps="docker compose ps"
```

### zsh history

履歴を大量に保存する。

```bash
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
```

履歴関連の設定。

```bash
setopt extended_history
setopt hist_ignore_dups
setopt share_history
```

### fzf

Homebrewでインストール。

```bash
brew install fzf
```

zshとの連携。

```bash
source <(fzf --zsh)
```

これにより、ターミナルで `Ctrl + R` を押すことで、過去のコマンドをfzfで検索できる。

例えば、

```text
Ctrl + R
↓
docker
↓
Docker関連の履歴だけに絞り込み
↓
↑ / ↓ で選択
↓
Enter
```

という操作ができる。

Rails + Docker開発で長いDockerコマンドを毎回入力する必要がなくなる。

## 注意事項

### .zsh_historyはGit管理しない

`.zsh_history` には実際に実行したコマンドが保存される。

APIキー、トークン、パスワードなどの機密情報が誤って含まれる可能性があるため、GitHubには保存しない。

管理するのは、

```text
.zshrc       # 管理する
.zsh_history # 管理しない
```

### 秘密情報をcommitしない

`.zshrc` などに以下を直接記述しない。

- APIキー
- アクセストークン
- パスワード
- 秘密鍵

dotfilesをGitHubへpushする前に、

```bash
git diff
```

や、

```bash
git diff --cached
```

で内容を確認する。

## 今後追加したいもの

- VS Code `settings.json`
- VS Code `keybindings.json`
- Git設定
- Alfred関連設定
- Homebrew環境の整理
- Mac初期セットアップ手順
