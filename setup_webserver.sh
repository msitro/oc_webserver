#!/bin/bash

# Variables
SERVER_NAME=$1
SERVER_ALIAS=$2
DOC_ROOT="/var/www/html"

if [[ -z "$SERVER_NAME" || -z "$SERVER_ALIAS" ]]; then
  echo "Usage: $0 <server_name> <server_alias>"
  exit 1
fi

# Update and upgrade system
sudo apt update && sudo apt upgrade -y

# Install PHP 8.0 and extensions
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install php8.0 php8.0-fpm php8.0-mysql php8.0-zip php8.0-xml php8.0-gd php8.0-curl php8.0-mbstring php8.0-bcmath php8.0-intl php8.0-soap -y

# Install Apache
sudo apt install apache2 libapache2-mod-fcgid -y
sudo a2enmod actions fcgid alias proxy_fcgi rewrite headers expires

# Configure Apache Virtual Host
sudo tee /etc/apache2/sites-available/opencart.conf > /dev/null <<EOL
<VirtualHost *:8080>
    ServerAdmin support@msit.ro
    ServerName $SERVER_NAME
    ServerAlias $SERVER_ALIAS
    DocumentRoot $DOC_ROOT

    <Directory $DOC_ROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.0-fpm.sock|fcgi://localhost"
    </FilesMatch>

    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json
    </IfModule>

    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType image/jpg "access plus 1 year"
        ExpiresByType image/jpeg "access plus 1 year"
        ExpiresByType image/gif "access plus 1 year"
        ExpiresByType image/png "access plus 1 year"
        ExpiresByType text/css "access plus 1 month"
        ExpiresByType application/pdf "access plus 1 month"
        ExpiresByType text/x-javascript "access plus 1 month"
        ExpiresByType application/x-shockwave-flash "access plus 1 month"
        ExpiresByType image/x-icon "access plus 1 year"
        ExpiresDefault "access plus 2 days"
    </IfModule>

    <IfModule mod_headers.c>
        Header set Cache-Control "max-age=2592000, public"
        Header unset ETag
        Header set Connection keep-alive
        Header always set X-Content-Type-Options "nosniff"
        Header always set X-Frame-Options "DENY"
        Header always set X-XSS-Protection "1; mode=block"
        Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    </IfModule>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL

# Enable site and reload Apache
sudo a2ensite opencart.conf
sudo systemctl reload apache2

# Configure PHP-FPM
sudo tee /etc/php/8.0/fpm/pool.d/www.conf > /dev/null <<EOL
[www]
user = www-data
group = www-data
listen = /run/php/php8.0-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
EOL

sudo systemctl restart php8.0-fpm

# Install and configure Varnish
sudo apt install varnish -y

sudo tee /etc/varnish/default.vcl > /dev/null <<EOL
vcl 4.1;

backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

sub vcl_recv {
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "Not allowed."));
        }
        return (hash);
    }
    if (req.method != "GET" && req.method != "HEAD" && req.method != "PUT" && req.method != "POST" && req.method != "TRACE" && req.method != "OPTIONS" && req.method != "DELETE" && req.method != "PATCH") {
        return (pipe);
    }
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }
    return (hash);
}

sub vcl_backend_response {
    if (bereq.uncacheable) {
        return (deliver);
    }
    set beresp.ttl = 1m;
    return (deliver);
}

sub vcl_deliver {
    return (deliver);
}
EOL

sudo sed -i 's/-a :6081/-a :80/' /lib/systemd/system/varnish.service
sudo systemctl daemon-reload
sudo systemctl restart varnish

# Install and configure Redis
sudo apt install redis-server -y
sudo systemctl enable redis-server
sudo systemctl start redis-server

# Install PHP Redis extension
sudo apt install php-redis -y

# Configure PHP (Full php.ini)
PHP_INI_FILE="/etc/php/8.0/fpm/php.ini"
if [ -f "$PHP_INI_FILE" ]; then
    sudo mv $PHP_INI_FILE ${PHP_INI_FILE}.bak
fi

sudo tee $PHP_INI_FILE > /dev/null <<EOL
[PHP]
engine = On
short_open_tag = Off
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
unserialize_callback_func =
serialize_precision = -1
disable_functions =
disable_classes =
zend.enable_gc = On
expose_php = Off
max_execution_time = 30
max_input_time = 60
memory_limit = 256M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
display_startup_errors = Off
log_errors = On
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
html_errors = Off
variables_order = "GPCS"
request_order = "GP"
register_argc_argv = Off
auto_globals_jit = On
post_max_size = 32M
auto_prepend_file =
auto_append_file =
default_mimetype = "text/html"
default_charset = "UTF-8"
doc_root =
user_dir =
enable_dl = Off
file_uploads = On
upload_max_filesize = 32M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60

[CLI Server]
cli_server.color = On

[Date]
date.timezone = UTC

[filter]

[iconv]

[intl]

[sqlite3]

[Pcre]
pcre.backtrack_limit = 1000000
pcre.recursion_limit = 100000

[Pdo]
pdo_odbc.connection_pooling = strict

[Phar]
phar.readonly = On
phar.require_hash = On

[mail function]
SMTP = localhost
smtp_port = 25
mail.add_x_header = Off

[SQL]
sql.safe_mode = Off

[ODBC]
odbc.allow_persistent = On
odbc.check_persistent = On
odbc.max_persistent = -1
odbc.max_links = -1
odbc.defaultlrl = 4096
odbc.defaultbinmode = 1

[Interbase]
ibase.allow_persistent = 1
ibase.max_persistent = -1
ibase.max_links = -1
ibase.timestampformat = "%Y-%m-%d %H:%M:%S"
ibase.dateformat = "%Y-%m-%d"
ibase.timeformat = "%H:%M:%S"

[MySQL]
mysql.allow_local_infile = On
mysql.allow_persistent = On
mysql.cache_size = 2000
mysql.max_persistent = -1
mysql.max_links = -1
mysql.default_port =
mysql.default_socket =
mysql.default_host =
mysql.default_user =
mysql.default_password =
mysql.connect_timeout = 60
mysql.trace_mode = Off

[mysqli]
mysqli.max_persistent = -1
mysqli.allow_persistent = On
mysqli.max_links = -1
mysqli.cache_size = 2000
mysqli.default_port = 3306
mysqli.default_socket =
mysqli.default_host =
mysqli.default_user =
mysqli.default_pw =
mysqli.reconnect = Off

[mysqlnd]
mysqlnd.collect_statistics = On
mysqlnd.collect_memory_statistics = Off

[OCI8]
oci8.privileged_connect = Off
oci8.max_persistent = -1
oci8.persistent_timeout = -1
oci8.ping_interval = 60
oci8.connection_class =
oci8.events = Off
oci8.statement_cache_size = 20

[PostgreSQL]
pgsql.allow_persistent = On
pgsql.auto_reset_persistent = Off
pgsql.max_persistent = -1
pgsql.max_links = -1
pgsql.ignore_notice = 0
pgsql.log_notice = 0

[bcmath]
bcmath.scale = 0

[browscap]

[Session]
session.save_handler = files
session.save_path = "/var/lib/php/sessions"
session.use_strict_mode = 0
session.use_cookies = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_path = /
session.cookie_domain =
session.cookie_httponly =
session.cookie_samesite =
session.serialize_handler = php
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
session.referer_check =
session.cache_limiter = nocache
session.cache_expire = 180
session.use_trans_sid = 0
session.sid_length = 26
session.trans_sid_tags = "a=href,area=href,frame=src,form="
session.sid_bits_per_character = 5

[Assertion]
zend.assertions = -1

[COM]
[mbstring]
[gd]
[exif]
[Tidy]
[soap]
[sysvshm]
[ldap]
[opcache]
[curl]
[openssl]
[redis]
EOL

# Restart services
sudo systemctl restart php8.0-fpm
sudo systemctl restart apache2
sudo systemctl restart varnish
sudo systemctl restart redis-server

echo "Server setup complete."
