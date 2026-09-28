# 色を使用
autoload -U compinit
compinit

export LSCOLORS=exfxcxdxbxegedabagacad
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'

alias ll="ls -la"
alias ls="ls -GF"
alias gls="gls --color"

zstyle ':completion:*' list-colors 'di=34' 'ln=35' 'so=32' 'ex=31' 'bd=46;34' 'cd=43;34'

# History
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

# タイムスタンプを記録
setopt extended_history

# 重複する履歴を保存しない
setopt hist_ignore_dups

# 複数のターミナル間で履歴を共有
setopt share_history

alias history='history -t "%F %T"'

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Rails / Bundler
alias be='bundle exec'

# Docker Compose
alias dcup="docker compose up -d"
alias dcdown="docker compose down"
alias dcexec="docker compose exec web"
alias dclog="docker compose logs -f"
alias dcps="docker compose ps"

# 同じコマンドの連続入力を記録しない
setopt hist_ignore_dups

# プロンプト
PROMPT='[%n %1~]$ '

# fzf
source <(fzf --zsh)
