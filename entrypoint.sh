#!/bin/bash
set -e

# SnapDeploy free containers have an ephemeral filesystem: anything written
# inside the container is gone on wake, restart or redeploy. So regenerate
# Typecho's config.inc.php from environment variables on every start.
# All content (posts, users, settings) lives in TiDB Cloud, not on disk.
#
# Only generate the config when the blog is already installed (the
# typecho_options table exists). With a config.inc.php present, Typecho's
# install.php redirects to the homepage instead of showing the setup wizard,
# so on a fresh database the config must stay absent until the wizard
# writes it. After installation, this probe succeeds and the config is
# regenerated on every start as before.
if [ -n "$DB_HOST" ] && [ -n "$DB_USER" ] && [ -n "$DB_PASSWORD" ] && [ -n "$DB_NAME" ]; then
  if php -r '
    try {
      $pdo = new PDO(
        "mysql:host=" . getenv("DB_HOST") . ";port=" . ((int) (getenv("DB_PORT") ?: 4000)) . ";dbname=" . getenv("DB_NAME"),
        getenv("DB_USER"),
        getenv("DB_PASSWORD"),
        [PDO::MYSQL_ATTR_SSL_CA => "/etc/ssl/certs/ca-certificates.crt", PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => true]
      );
      $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
      $pdo->query("SELECT 1 FROM `typecho_options` LIMIT 1");
      exit(0);
    } catch (Throwable $e) {
      exit(1);
    }
  '; then
  cat > /var/www/html/config.inc.php <<'PHPCONFIG'
<?php
/** 定义根目录 */
define('__TYPECHO_ROOT_DIR__', dirname(__FILE__));
/** 定义插件目录(相对路径) */
define('__TYPECHO_PLUGIN_DIR__', '/usr/plugins');
/** 定义模板目录(相对路径) */
define('__TYPECHO_THEME_DIR__', '/usr/themes');
/** 定义后台路径(相对路径) */
define('__TYPECHO_ADMIN_DIR__', '/admin/');
/** 定义上传目录 */
define('__TYPECHO_UPLOAD_DIR__', '/usr/uploads');
/** 设置包含路径 */
@set_include_path(get_include_path() . PATH_SEPARATOR .
__TYPECHO_ROOT_DIR__ . '/var' . PATH_SEPARATOR .
__TYPECHO_ROOT_DIR__ . '/usr');
/** 载入 */
require_once __TYPECHO_ROOT_DIR__ . '/var/Typecho/Common.php';
/** 程序初始化 */
\Typecho\Common::init();
/** 定义数据库参数 */
$db = new \Typecho\Db('Pdo_Mysql', 'typecho_');
$db->addServer(array (
  'host' => getenv('DB_HOST'),
  'user' => getenv('DB_USER'),
  'password' => getenv('DB_PASSWORD'),
  'charset' => 'utf8mb4',
  'port' => (int) (getenv('DB_PORT') ?: 4000),
  'database' => getenv('DB_NAME'),
  'engine' => 'InnoDB',
  'sslCa' => '/etc/ssl/certs/ca-certificates.crt',
  'sslVerify' => true,
), \Typecho\Db::READ | \Typecho\Db::WRITE);
\Typecho\Db::set($db);
PHPCONFIG
    chown www-data:www-data /var/www/html/config.inc.php
  else
    rm -f /var/www/html/config.inc.php
  fi
fi

exec "$@"
