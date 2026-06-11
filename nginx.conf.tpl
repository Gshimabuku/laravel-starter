services:
  app:
    build:
      context: ./docker/php
      args:
        PHP_VERSION: {{PHP_VERSION}}
    container_name: {{PROJECT_NAME}}_app
    volumes:
      - ./src:/var/www/html
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - {{PROJECT_NAME}}_network

  web:
    image: nginx:alpine
    container_name: {{PROJECT_NAME}}_web
    ports:
      - "{{APP_PORT}}:80"
    volumes:
      - ./src:/var/www/html
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - app
    networks:
      - {{PROJECT_NAME}}_network

  db:
    image: mysql:8.0
    container_name: {{PROJECT_NAME}}_db
    environment:
      MYSQL_DATABASE: {{DB_NAME}}
      MYSQL_USER: {{DB_USER}}
      MYSQL_PASSWORD: {{DB_PASSWORD}}
      MYSQL_ROOT_PASSWORD: root
    ports:
      - "{{DB_PORT}}:3306"
    volumes:
      - {{PROJECT_NAME}}_db_data:/var/lib/mysql
      - ./docker/mysql/my.cnf:/etc/mysql/conf.d/my.cnf
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-proot"]
      interval: 5s
      timeout: 5s
      retries: 10
    networks:
      - {{PROJECT_NAME}}_network

  redis:
    image: redis:alpine
    container_name: {{PROJECT_NAME}}_redis
    ports:
      - "{{REDIS_PORT}}:6379"
    volumes:
      - {{PROJECT_NAME}}_redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - {{PROJECT_NAME}}_network

volumes:
  {{PROJECT_NAME}}_db_data:
  {{PROJECT_NAME}}_redis_data:

networks:
  {{PROJECT_NAME}}_network:
    driver: bridge
