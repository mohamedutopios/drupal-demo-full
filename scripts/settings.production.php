<?php

/**
 * @file
 * settings.php — Environnement de PRODUCTION (VM Debian / Apache / MySQL).
 *
 * ⚠️  Ce fichier NE DOIT PAS être commité dans Git.
 *     Il est créé manuellement sur le serveur lors de la mise en production.
 *     Chemin sur le serveur : /var/www/drupal/web/sites/default/settings.php
 */

// ── Base de données production ────────────────────────────────────────────
$databases['default']['default'] = [
  'driver'    => 'mysql',
  'host'      => '127.0.0.1',
  'database'  => getenv('DB_NAME') ?: 'drupal_prod',
  'username'  => getenv('DB_USER') ?: 'drupal',
  'password'  => getenv('DB_PASS') ?: 'CHANGE_ME',
  'port'      => '3306',
  'prefix'    => '',
  'namespace' => 'Drupal\Core\Database\Driver\mysql',
  'autoload'  => 'core/modules/mysql/src/Driver/Database/mysql/',
  'init_commands' => [
    'isolation_level' => 'SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED',
  ],
];

// ── Clé de hachage (générer avec drush) ──────────────────────────────────
// drush eval "echo \Drupal\Component\Utility\Crypt::randomBytesBase64(55)"
$settings['hash_salt'] = getenv('DRUPAL_HASH_SALT') ?: 'CHANGE_THIS_HASH_SALT';

// ── Chemins ───────────────────────────────────────────────────────────────
$settings['config_sync_directory'] = '../config/sync';
$settings['file_private_path']     = '../private';

// ── Trusted host patterns ─────────────────────────────────────────────────
$settings['trusted_host_patterns'] = [
  '^monsite\.example\.com$',
  '^www\.monsite\.example\.com$',
];

// ── Performance production ────────────────────────────────────────────────
$settings['container_yamls'][] = $app_root . '/sites/default/services.yml';

// Cache de rendu activé en production
$config['system.performance']['cache']['page']['use_internal'] = TRUE;
$config['system.performance']['css']['preprocess']             = TRUE;
$config['system.performance']['js']['preprocess']              = TRUE;

// ── Désactiver le mode débogage ───────────────────────────────────────────
$config['system.logging']['error_level'] = 'none';

// ── Reverse proxy (si derrière Nginx/load balancer) ──────────────────────
# $settings['reverse_proxy']         = TRUE;
# $settings['reverse_proxy_addresses'] = ['127.0.0.1'];
