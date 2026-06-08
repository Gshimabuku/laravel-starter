# ─────────────────────────────────────
# {{PROJECT_NAME}} - Laravel開発コマンド
# ─────────────────────────────────────

.PHONY: up down restart build destroy bash bash-web db \
        logs logs-app migrate fresh seed tinker cache-clear \
        routes storage-link composer require npm dev build-assets \
        test test-v ps

# ─── コンテナ操作 ───
up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

build:
	docker compose up -d --build

destroy:
	docker compose down -v

# ─── シェル・ログ ───
bash:
	docker compose exec app bash

bash-web:
	docker compose exec web sh

db:
	docker compose exec db mysql -u {{DB_USER}} -p{{DB_PASSWORD}} {{DB_NAME}}

logs:
	docker compose logs -f

logs-app:
	docker compose logs -f app

# ─── Laravel操作 ───
migrate:
	docker compose exec app php artisan migrate

fresh:
	docker compose exec app php artisan migrate:fresh --seed

seed:
	docker compose exec app php artisan db:seed

tinker:
	docker compose exec app php artisan tinker

cache-clear:
	docker compose exec app php artisan cache:clear
	docker compose exec app php artisan config:clear
	docker compose exec app php artisan route:clear
	docker compose exec app php artisan view:clear

routes:
	docker compose exec app php artisan route:list

storage-link:
	docker compose exec app php artisan storage:link

# ─── パッケージ管理 ───
composer:
	docker compose exec app composer install

require:
	docker compose exec app composer require $(pkg)

npm:
	docker compose exec app npm install

dev:
	docker compose exec app npm run dev

build-assets:
	docker compose exec app npm run build

# ─── テスト ───
test:
	docker compose exec app php artisan test

test-v:
	docker compose exec app php artisan test --verbose

# ─── 状態確認 ───
ps:
	docker compose ps
