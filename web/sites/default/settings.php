<?php

/**
 * @file
 * Drupal settings — Environnement local Lando.
 */

// ── Base de données Lando ──────────────────────────────────────────────────
$databases['default']['default'] = [
  'driver'    => 'mysql',
  'host'      => 'database',
  'database'  => 'drupal',
  'username'  => 'drupal',
  'password'  => 'drupal',
  'port'      => '3306',
  'prefix'    => '',
  'namespace' => 'Drupal\Core\Database\Driver\mysql',
  'autoload'  => 'core/modules/mysql/src/Driver/Database/mysql/',
];

// ── Clé de hachage ────────────────────────────────────────────────────────
// Générer avec : drush eval "echo \Drupal\Component\Utility\Crypt::randomBytesBase64(55)"
$settings['hash_salt'] = 'CHANGE_THIS_HASH_SALT_IN_PRODUCTION_USE_DRUSH_TO_GENERATE';

// ── Chemins de configuration ───────────────────────────────────────────────
$settings['config_sync_directory'] = '../config/sync';

// ── Fichiers privés ────────────────────────────────────────────────────────
$settings['file_private_path'] = '../private';

// ── Trusted host patterns ──────────────────────────────────────────────────
$settings['trusted_host_patterns'] = [
  '^drupal-crud\.lndo\.site$',
  '^localhost$',
  '^127\.0\.0\.1$',
];

// ── Désactivation du cache en développement ───────────────────────────────
if (file_exists($app_root . '/' . $site_path . '/settings.local.php')) {
  include $app_root . '/' . $site_path . '/settings.local.php';
}
