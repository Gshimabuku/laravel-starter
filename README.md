#!/bin/bash
set -e

# ─────────────────────────────────────────
# new-laravel.sh
# 役割: GitHubリポジトリ作成 + Docker構成ファイル生成 + 初回push
# 対応OS: Ubuntu (WSL2)
# ─────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
PROJECTS_DIR="/var/local"
GITHUB_USER="Gshimabuku"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}🚀 Laravel 新規プロジェクト作成${NC}"
echo -e "${CYAN}──────────────────────────────────────${NC}"

# ─── 入力関数 ───
prompt() {
    local message="$1"
    local default="$2"
    local result

    if [ -n "$default" ]; then
        read -rp "$(echo -e "${BOLD}${message}${NC} [${default}]: ")" result
        echo "${result:-$default}"
    else
        while true; do
            read -rp "$(echo -e "${BOLD}${message}${NC}: ")" result
            if [ -n "$result" ]; then
                echo "$result"
                break
            fi
            echo -e "${RED}  ※ 必須項目です${NC}" >&2
        done
    fi
}

# ─── 対話式入力 ───
PROJECT_NAME=$(prompt "プロジェクト名（英数字・ハイフン・アンダースコア）")

if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "${RED}エラー: プロジェクト名は英数字・ハイフン・アンダースコアのみ使用可能です${NC}"
    exit 1
fi

LARAVEL_VERSION=$(prompt "Laravel バージョン" "11")
PHP_VERSION=$(prompt "PHP バージョン" "8.3")
APP_PORT=$(prompt "アプリ ポート番号" "8080")
DB_NAME=$(prompt "DB データベース名" "${PROJECT_NAME}_db")
DB_USER=$(prompt "DB ユーザー名" "laravel")
DB_PASSWORD=$(prompt "DB パスワード" "secret")
DB_PORT=$(prompt "DB ポート番号" "3306")
REDIS_PORT=$(prompt "Redis ポート番号" "6379")
REPO_VISIBILITY=$(prompt "GitHubリポジトリの公開設定 (public/private)" "private")

PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"

echo ""
echo -e "${CYAN}──────────────────────────────────────${NC}"
echo -e "${BOLD}以下の設定で作成します：${NC}"
echo -e "  プロジェクト名    : ${GREEN}$PROJECT_NAME${NC}"
echo -e "  Laravel バージョン: ${GREEN}$LARAVEL_VERSION${NC}"
echo -e "  PHP バージョン    : ${GREEN}$PHP_VERSION${NC}"
echo -e "  アプリ URL        : ${GREEN}http://localhost:$APP_PORT${NC}"
echo -e "  DB 名             : ${GREEN}$DB_NAME${NC}"
echo -e "  DB ユーザー       : ${GREEN}$DB_USER${NC}"
echo -e "  DB ポート         : ${GREEN}$DB_PORT${NC}"
echo -e "  Redis ポート      : ${GREEN}$REDIS_PORT${NC}"
echo -e "  GitHub リポジトリ : ${GREEN}https://github.com/$GITHUB_USER/$PROJECT_NAME ($REPO_VISIBILITY)${NC}"
echo -e "  作成先            : ${GREEN}$PROJECT_DIR${NC}"
echo -e "${CYAN}──────────────────────────────────────${NC}"
echo ""

read -rp "$(echo -e "${BOLD}よろしいですか？ [y/N]: ${NC}")" CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}キャンセルしました${NC}"
    exit 0
fi

# ─── [1/5] /var/local/ 権限確認 ───
echo ""
echo -e "${CYAN}[1/5] /var/local/ の権限確認中...${NC}"

if [ ! -w "$PROJECTS_DIR" ]; then
    echo -e "${YELLOW}  書き込み権限がありません。権限を付与します...${NC}"
    sudo chown "$USER" "$PROJECTS_DIR"
    echo -e "${GREEN}  権限付与完了${NC}"
else
    echo -e "${GREEN}  権限OK${NC}"
fi

if [ -d "$PROJECT_DIR" ]; then
    echo -e "${RED}エラー: $PROJECT_DIR は既に存在します${NC}"
    exit 1
fi

# ─── [2/5] gh CLI 確認・インストール ───
echo ""
echo -e "${CYAN}[2/5] GitHub CLI 確認中...${NC}"

if ! command -v gh &>/dev/null; then
    echo -e "${YELLOW}  GitHub CLI が見つかりません。インストールします...${NC}"
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y gh
    echo -e "${GREEN}  GitHub CLI インストール完了${NC}"
fi

# ログイン確認
if ! gh auth status &>/dev/null; then
    echo -e "${YELLOW}  GitHub にログインしてください${NC}"
    gh auth login
fi

echo -e "${GREEN}  GitHub CLI OK${NC}"

# ─── [3/5] ディレクトリ・設定ファイル生成 ───
echo ""
echo -e "${CYAN}[3/5] ディレクトリ・設定ファイル生成中...${NC}"

mkdir -p "$PROJECT_DIR/docker/php"
mkdir -p "$PROJECT_DIR/docker/nginx"
mkdir -p "$PROJECT_DIR/docker/mysql"
mkdir -p "$PROJECT_DIR/src"

# src/ を git 管理するための .gitkeep
touch "$PROJECT_DIR/src/.gitkeep"

generate_from_template() {
    local template="$TEMPLATES_DIR/$1"
    local output="$2"

    if [ ! -f "$template" ]; then
        echo -e "${RED}エラー: テンプレートが見つかりません: $template${NC}"
        exit 1
    fi

    sed \
        -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
        -e "s|{{LARAVEL_VERSION}}|$LARAVEL_VERSION|g" \
        -e "s|{{PHP_VERSION}}|$PHP_VERSION|g" \
        -e "s|{{APP_PORT}}|$APP_PORT|g" \
        -e "s|{{DB_NAME}}|$DB_NAME|g" \
        -e "s|{{DB_USER}}|$DB_USER|g" \
        -e "s|{{DB_PASSWORD}}|$DB_PASSWORD|g" \
        -e "s|{{DB_PORT}}|$DB_PORT|g" \
        -e "s|{{REDIS_PORT}}|$REDIS_PORT|g" \
        "$template" > "$output"
}

generate_from_template "docker-compose.yml.tpl"  "$PROJECT_DIR/docker-compose.yml"
generate_from_template "Dockerfile.tpl"           "$PROJECT_DIR/docker/php/Dockerfile"
generate_from_template "nginx.conf.tpl"           "$PROJECT_DIR/docker/nginx/default.conf"
generate_from_template "my.cnf.tpl"               "$PROJECT_DIR/docker/mysql/my.cnf"
generate_from_template "Makefile.tpl"             "$PROJECT_DIR/Makefile"

# clone-laravel.sh をプロジェクトにコピー
cp "$SCRIPT_DIR/clone-laravel.sh" "$PROJECT_DIR/clone-laravel.sh"
chmod +x "$PROJECT_DIR/clone-laravel.sh"

# .env.example を生成（clone-laravel.sh が参照するデフォルト値として使用）
cat > "$PROJECT_DIR/.env.example" << ENV_EOF
APP_NAME=${PROJECT_NAME}
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:${APP_PORT}

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}

BROADCAST_DRIVER=log
CACHE_DRIVER=redis
FILESYSTEM_DISK=local
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
SESSION_LIFETIME=120

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379
ENV_EOF

# .gitignore 生成
cat > "$PROJECT_DIR/.gitignore" << 'GITIGNORE_EOF'
src/.env
src/vendor/
src/node_modules/
src/storage/logs/*
src/.gitkeep
*.log
.DS_Store
GITIGNORE_EOF

echo -e "${GREEN}  ファイル生成完了${NC}"

# ─── [4/5] GitHub リポジトリ作成 ───
echo ""
echo -e "${CYAN}[4/5] GitHub リポジトリ作成中...${NC}"

cd "$PROJECT_DIR"
git init
git add .
git commit -m "initial commit: Laravel ${LARAVEL_VERSION} / PHP ${PHP_VERSION}"

gh repo create "${GITHUB_USER}/${PROJECT_NAME}" \
    --"${REPO_VISIBILITY}" \
    --source=. \
    --remote=origin \
    --push

echo -e "${GREEN}  GitHubリポジトリ作成・push完了${NC}"
echo -e "  🔗 https://github.com/${GITHUB_USER}/${PROJECT_NAME}${NC}"

# ─── [5/5] 完了 ───
echo ""
echo -e "${GREEN}${BOLD}✅ 新規プロジェクト作成完了！${NC}"
echo -e "${CYAN}──────────────────────────────────────${NC}"
echo -e "${BOLD}次のステップ：${NC}"
echo -e ""
echo -e "  ${BOLD}1. プロジェクトディレクトリへ移動${NC}"
echo -e "     cd $PROJECT_DIR"
echo -e ""
echo -e "  ${BOLD}2. Laravel環境を構築${NC}"
echo -e "     ./clone-laravel.sh"
echo -e "${CYAN}──────────────────────────────────────${NC}"
