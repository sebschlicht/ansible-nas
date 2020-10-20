<?php
$CONFIG = array (
  'passwordsalt' => '{{ nc_passwordsalt }}',
  'secret' => '{{ nc_secret }}',
  'trusted_domains' =>
  array (
    0 => 'localhost',
    1 => '{{ nas.domain }}',
  ),
  'datadirectory' => '{{ nextcloud.data_path }}',
  'dbtype' => 'mysql',
  'overwrite.cli.url' => 'http://{{ nas.domain }}',
  'dbname' => '{{ db_name }}',
  'dbhost' => 'localhost',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => '{{ db_user_name }}',
  'dbpassword' => '{{ db_user_password }}',
  'installed' => true,
  'memcache.local' => '\OC\Memcache\APCu',
  'memcache.locking' => '\OC\Memcache\Redis',
  'redis' => [
      'host'     => '/var/run/redis/redis-server.sock',
      'port'     => 0,
      'timeout'  => 1.5,
  ],
);
