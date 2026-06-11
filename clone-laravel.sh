#!/bin/bash
set -e

# ─────────────────────────────────────────
# clone-laravel.sh
# 役割: Laravelのインストール・Docker環境構築
#       新規プロジェクト・既存プロジェクト共通
# 実行場所: /var/local/{プロジェクト名}/
# 対応OS: Ubuntu (WSL2)
# ─────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
ENV_EXAMPLE="$PROJECT_DIR/.env.example"

echo ""
echo -e "${CYAN}${BOLD}🔧 Laravel 環境構築: ${PROJECT_NAME}${NC}"
echo -e "${CYAN}──────────────────────────────────────${NC}"

# ─── 実行場所の確認 ───
if [ ! -f "$PROJECT_DIR/docker-compose.yml" ]; then
    echo -e "${RED}エラー: docker-compose.yml が見つかりません${NC}"
    echo -e "${RED}       /var/local/{プロジェクト名}/ で実行してください${NC}"
    exit 1
fi

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

# ─── .env.example から既存の設定値を読み込む ───
load_env_value() {
    local key="$1"
    local default="$2"
    if [ -f "$ENV_EXAMPLE" ]; then
        local value
        value=$(grep "^${key}=" "$ENV_EXAMPLE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

DEFAULT_APP_PORT=$(load_env_value "APP_URL" "8080" | grep -oP '(?<=:)\d+' || echo "8080")
DEFAULT_DB_NAME=$(load_env_value "DB_DATABASE" "${PROJECT_NAME}_db")
DEFAULT_DB_USER=$(load_env_value "DB_USERNAME" "laravel")
DEFAULT_DB_PASSWORD=$(load_env_value "DB_PASSWORD" "secret")
DEFAULT_DB_PORT=$(load_env_value "DB_PORT" "3306")
DEFAULT_REDIS_PORT=$(load_env_value "REDIS_PORT" "6379")
DEFAULT_LARAVEL_VERSION=$(load_env_value "LARAVEL_VERSION" "11")
DEFAULT_PHP_VERSION=$(load_env_value "PHP_VERSION" "8.3")

# ─── 新規 or 既存の判定 ───
IS_NEW=false
if [ ! -d "$PROJECT_DIR/src" ] || [ -z "$(ls -A "$PROJECT_DIR/src" 2>/dev/null | grep -v '.gitkeep')" ]; then
    IS_NEW=true
fi

if [ "$IS_NEW" = true ]; then
    echo -e "${CYAN}  モード: 新規インストール${NC}"
else
    echo -e "${CYAN}  モード: 既存プロジェクト再構築${NC}"
fi

echo ""

# ─── .env が存在しない場合のみ入力を求める ───
if [ ! -f "$PROJECT_DIR/src/.env" ]; then
    echo -e "${YELLOW}  .env が見つかりません。設定値を入力してください。${NC}"
    echo -e "${YELLOW}  （Enterキーで .env.example の値を使用）${NC}"
    echo ""

    APP_PORT=$(prompt "アプリ ポート番号" "$DEFAULT_APP_PORT")
    DB_NAME=$(prompt "DB データベース名" "$DEFAULT_DB_NAME")
    DB_USER=$(prompt "DB ユーザー名" "$DEFAULT_DB_USER")
    DB_PASSWORD=$(prompt "DB パスワード" "$DEFAULT_DB_PASSWORD")
    DB_PORT=$(prompt "DB ポート番号" "$DEFAULT_DB_PORT")
    REDIS_PORT=$(prompt "Redis ポート番号" "$DEFAULT_REDIS_PORT")

    if [ "$IS_NEW" = true ]; then
        LARAVEL_VERSION=$(prompt "Laravel バージョン" "$DEFAULT_LARAVEL_VERSION")
        PHP_VERSION=$(prompt "PHP バージョン" "$DEFAULT_PHP_VERSION")
    fi

    NEED_ENV=true
else
    echo -e "${GREEN}  .env を検出しました。既存の設定を使用します。${NC}"
    APP_PORT=$DEFAULT_APP_PORT
    DB_NAME=$DEFAULT_DB_NAME
    DB_USER=$DEFAULT_DB_USER
    DB_PASSWORD=$DEFAULT_DB_PASSWORD
    DB_PORT=$DEFAULT_DB_PORT
    REDIS_PORT=$DEFAULT_REDIS_PORT
    LARAVEL_VERSION=$DEFAULT_LARAVEL_VERSION
    PHP_VERSION=$DEFAULT_PHP_VERSION
    NEED_ENV=false
fi

echo ""
echo -e "${CYAN}──────────────────────────────────────${NC}"
echo -e "${BOLD}以下の設定で環境を構築します：${NC}"
echo -e "  プロジェクト名: ${GREEN}$PROJECT_NAME${NC}"
echo -e "  アプリ URL    : ${GREEN}http://localhost:$APP_PORT${NC}"
echo -e "  DB 名         : ${GREEN}$DB_NAME${NC}"
echo -e "  DB ユーザー   : ${GREEN}$DB_USER${NC}"
echo -e "  DB ポート     : ${GREEN}$DB_PORT${NC}"
echo -e "  Redis ポート  : ${GREEN}$REDIS_PORT${NC}"
echo -e "${CYAN}──────────────────────────────────────${NC}"
echo ""

read -rp "$(echo -e "${BOLD}よろしいですか？ [y/N]: ${NC}")" CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}キャンセルしました${NC}"
    exit 0
fi

# ─── [1/4] Docker 確認 ───
echo ""
echo -e "${CYAN}[1/4] Docker 確認中...${NC}"

if ! command -v docker &>/dev/null; then
    echo -e "${YELLOW}  Docker が見つかりません。インストールします...${NC}"
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    echo -e "${GREEN}  Docker インストール完了${NC}"
    echo -e "${YELLOW}  ※ ログアウト・ログインが必要な場合があります${NC}"
else
    echo -e "${GREEN}  Docker OK ($(docker --version | cut -d' ' -f3 | tr -d ','))${NC}"
fi

if ! docker compose version &>/dev/null; then
    echo -e "${RED}エラー: Docker Compose が見つかりません${NC}"
    exit 1
fi
echo -e "${GREEN}  Docker Compose OK${NC}"

# ─── [2/4] コンテナ起動 ───
echo ""
echo -e "${CYAN}[2/4] Dockerコンテナ起動中...${NC}"

cd "$PROJECT_DIR"
docker compose up -d --build
echo -e "${GREEN}  コンテナ起動完了${NC}"

# ─── [3/4] Laravel インストール or 既存復元 ───
echo ""

if [ "$IS_NEW" = true ]; then
    echo -e "${CYAN}[3/4] Laravel インストール中...${NC}"

    docker compose exec app composer create-project \
        "laravel/laravel:^${LARAVEL_VERSION}" \
        /tmp/laravel_new \
        --prefer-dist \
        --no-interaction

    docker compose exec -u root app bash -c \
        "cp -r /tmp/laravel_new/. /var/www/html/ && \
         chown -R www-data:www-data /var/www/html/ && \
         rm -rf /tmp/laravel_new"

    echo -e "${GREEN}  Laravel インストール完了${NC}"
else
    echo -e "${CYAN}[3/4] 既存パッケージ復元中...${NC}"

    docker compose exec app composer install --no-interaction
    echo -e "${GREEN}  composer install 完了${NC}"
fi

# ─── [4/4] Laravel 初期設定 ───
echo ""
echo -e "${CYAN}[4/4] Laravel 初期設定中...${NC}"

if [ "$NEED_ENV" = true ]; then
    docker compose exec app bash -c "cat > /var/www/html/.env" << ENV_EOF
APP_NAME=${PROJECT_NAME}
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:${APP_PORT}

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
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
    echo -e "${GREEN}  .env 生成完了${NC}"
fi

docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate
docker compose exec app php artisan storage:link

echo -e "${GREEN}  Laravel 初期設定完了${NC}"

# ─── 完了メッセージ ───
echo ""
echo -e "${GREEN}${BOLD}✅ 環境構築完了！${NC}"
echo -e "${CYAN}──────────────────────────────────────${NC}"
echo -e "  🌐 アプリ URL   : ${BOLD}http://localhost:${APP_PORT}${NC}"
echo -e "  📁 プロジェクト : ${BOLD}$PROJECT_DIR${NC}"
echo -e "  📂 ソースコード : ${BOLD}$PROJECT_DIR/src${NC}"
echo ""
echo -e "${BOLD}よく使うコマンド:${NC}"
echo -e "  make up          # コンテナ起動"
echo -e "  make down        # コンテナ停止"
echo -e "  make bash        # コンテナに入る"
echo -e "  make migrate     # マイグレーション実行"
echo -e "  make fresh       # DB初期化+シード"
echo -e "  make logs        # ログ確認"
echo -e "${CYAN}──────────────────────────────────────${NC}"
