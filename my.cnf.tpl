server {
    listen 80;
    server_name localhost;
    root /var/www/html/public;
    index index.php index.html;

    access_log /var/log/nginx/{{PROJECT_NAME}}_access.log;
    error_log  /var/log/nginx/{{PROJECT_NAME}}_error.log;

    client_max_body_size 100M;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass app:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
