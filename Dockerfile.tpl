[mysqld]
character-set-server = utf8mb4
collation-server     = utf8mb4_unicode_ci
default-time-zone    = '+09:00'
max_allowed_packet   = 256M
innodb_buffer_pool_size = 256M
slow_query_log       = 1
slow_query_log_file  = /var/log/mysql/slow.log
long_query_time      = 1

[mysql]
default-character-set = utf8mb4

[client]
default-character-set = utf8mb4
