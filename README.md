# 🚀 laravel-starter

Laravel ローカル開発環境を自動構築するツール。

## 必要環境

- Ubuntu（WSL2）
- Docker / Docker Compose
- GitHub CLI（`gh`）※ new-laravel.sh が自動インストール

---

## ファイル構成

```
~/laravel-starter/
├── new-laravel.sh       # 新規プロジェクト作成 + GitHubリポジトリ作成
├── clone-laravel.sh     # Laravel環境構築（新規・既存共通）
└── templates/           # Docker構成ファイルのテンプレート
```

---

## 使い方

### セットアップ（初回のみ）

```bash
git clone https://github.com/Gshimabuku/laravel-starter.git ~/laravel-starter
chmod +x ~/laravel-starter/new-laravel.sh
chmod +x ~/laravel-starter/clone-laravel.sh
```

---

### 新規プロジェクトの作成

```bash
# 1. 新規プロジェクト作成 + GitHubリポジトリ作成
~/laravel-starter/new-laravel.sh

# 2. プロジェクトディレクトリへ移動
cd /var/local/{プロジェクト名}

# 3. Laravel環境構築
./clone-laravel.sh
```

---

### 既存プロジェクトの再構築（別端末・再セットアップ）

```bash
# 1. /var/local/ へ移動
cd /var/local

# 2. GitHubからclone
git clone https://github.com/Gshimabuku/{プロジェクト名}.git

# 3. プロジェクトディレクトリへ移動
cd /var/local/{プロジェクト名}

# 4. Laravel環境構築
./clone-laravel.sh
```

---

## 生成されるプロジェクト構成

```
/var/local/{プロジェクト名}/
├── docker-compose.yml
├── docker/
│   ├── php/Dockerfile
│   ├── nginx/default.conf
│   └── mysql/my.cnf
├── Makefile
├── clone-laravel.sh       # 環境構築スクリプト
├── .env.example           # DB・ポート等のデフォルト値
├── .gitignore
└── src/                   # Laravelソース（本番デプロイ対象）
```

---

## Makefileコマンド一覧

```bash
make up           # コンテナ起動
make down         # コンテナ停止
make restart      # コンテナ再起動
make build        # イメージ再ビルド＆起動
make destroy      # コンテナ＆ボリューム削除

make bash         # appコンテナにbashで入る
make db           # MySQLに接続
make logs         # ログをリアルタイム表示

make migrate      # マイグレーション実行
make fresh        # DB初期化＋マイグレーション＋シード
make seed         # シードのみ実行
make tinker       # php artisan tinker
make cache-clear  # キャッシュクリア

make composer     # composer install
make require pkg=xxx  # composer require
make test         # テスト実行
make ps           # コンテナ状態確認
```

---

## 本番デプロイ

```
デプロイ対象: /var/local/{プロジェクト名}/src/
Docker関連ファイルは本番環境では不要です。
```

---

## Docker構成

| サービス | イメージ | 役割 |
|---------|---------|------|
| app | php:{version}-fpm | Laravel実行環境 |
| web | nginx:alpine | Webサーバー |
| db | mysql:8.0 | データベース |
| redis | redis:alpine | キャッシュ・セッション・Queue |
