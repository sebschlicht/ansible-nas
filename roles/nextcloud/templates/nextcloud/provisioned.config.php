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
  'mail_smtpmode' => 'smtp',
  'mail_sendmailmode' => 'smtp',
  'mail_from_address' => 'pi.ko',
  'mail_domain' => 'sschlicht.de',
  'mail_smtpsecure' => 'ssl',
  'mail_smtpauthtype' => 'LOGIN',
  'mail_smtpauth' => 1,
  "mail_smtphost" => "{{ mailing.server }}",
  'mail_smtpport' => '465',
  "mail_smtpname" => "{{ mailing.user }}",
  "mail_smtppassword" => "{{ mailing.password }}",
);
