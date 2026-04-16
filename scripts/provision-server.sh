#!/usr/bin/env bash
# =============================================================================
# provision-server.sh
# Script de provisionnement initial de la VM Debian pour Drupal 10
# Usage : sudo bash provision-server.sh
# =============================================================================

set -Eeuo pipefail

# ── Variables à adapter ───────────────────────────────────────────────────
DEPLOY_USER="deploy"
DEPLOY_PATH="/var/www/drupal"
DB_NAME="drupal_prod"
DB_USER="drupal"
DB_PASS="$(openssl rand -base64 20 | tr -d '\n')"
PHP_VERSION="8.2"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Provisionnement VM Debian — Drupal 10 + Apache"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

export DEBIAN_FRONTEND=noninteractive

# ── Vérification root ─────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
  echo "Ce script doit être exécuté avec sudo ou en root."
  exit 1
fi

# ── 1. Mise à jour système ────────────────────────────────────────────────
echo "[1/9] Mise à jour des paquets..."
apt-get update -qq
apt-get upgrade -y -qq

# ── 2. Dépendances de base ────────────────────────────────────────────────
echo "[2/9] Installation des dépendances de base..."
apt-get install -y -qq \
  curl \
  wget \
  git \
  unzip \
  rsync \
  ca-certificates \
  lsb-release \
  gnupg \
  apt-transport-https \
  openssl

# ── 3. PHP 8.2 via dépôt Sury ────────────────────────────────────────────
echo "[3/9] Ajout du dépôt Sury et installation de PHP ${PHP_VERSION}..."

# Ajout de la clé GPG et du dépôt Sury (source officielle PHP pour Debian)
curl -sSLo /tmp/php-sury.gpg https://packages.sury.org/php/apt.gpg
install -D -o root -g root -m 644 /tmp/php-sury.gpg /etc/apt/trusted.gpg.d/php-sury.gpg
rm -f /tmp/php-sury.gpg

echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" \
  > /etc/apt/sources.list.d/php-sury.list

apt-get update -qq

# Installation d'Apache + PHP 8.2 + extensions Drupal
apt-get install -y -qq \
  apache2 \
  libapache2-mod-php${PHP_VERSION} \
  php${PHP_VERSION} \
  php${PHP_VERSION}-cli \
  php${PHP_VERSION}-common \
  php${PHP_VERSION}-mysql \
  php${PHP_VERSION}-xml \
  php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-curl \
  php${PHP_VERSION}-gd \
  php${PHP_VERSION}-zip \
  php${PHP_VERSION}-intl \
  php${PHP_VERSION}-opcache \
  php${PHP_VERSION}-apcu \
  php${PHP_VERSION}-bcmath

# Tuning php.ini
PHP_INI="/etc/php/${PHP_VERSION}/apache2/php.ini"

if [[ -f "${PHP_INI}" ]]; then
  sed -i 's/^memory_limit = .*/memory_limit = 256M/'             "${PHP_INI}"
  sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 32M/' "${PHP_INI}"
  sed -i 's/^post_max_size = .*/post_max_size = 32M/'             "${PHP_INI}"
  sed -i 's/^max_execution_time = .*/max_execution_time = 120/'   "${PHP_INI}"

  if grep -q '^;date.timezone' "${PHP_INI}"; then
    sed -i 's#^;date.timezone.*#date.timezone = Europe/Paris#' "${PHP_INI}"
  else
    echo 'date.timezone = Europe/Paris' >> "${PHP_INI}"
  fi

  if ! grep -q '^opcache.enable=1' "${PHP_INI}"; then
    cat >> "${PHP_INI}" <<'EOF'

; Drupal recommended OPcache tuning
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=60
EOF
  fi
else
  echo "❌ Fichier php.ini introuvable : ${PHP_INI}"
  exit 1
fi

echo "  → PHP $(php -r 'echo PHP_VERSION;') installé"

# ── 4. Apache ─────────────────────────────────────────────────────────────
echo "[4/9] Configuration d'Apache..."
a2enmod rewrite headers expires deflate php${PHP_VERSION}
systemctl enable apache2
systemctl restart apache2

# ── 5. Base de données ────────────────────────────────────────────────────
echo "[5/9] Installation de MariaDB..."
apt-get install -y -qq mariadb-server
systemctl enable mariadb
systemctl restart mariadb

mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
  IDENTIFIED BY '${DB_PASS}';

GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

echo "  → DB créée    : ${DB_NAME}"
echo "  → Utilisateur : ${DB_USER}"

# ── 6. Composer ───────────────────────────────────────────────────────────
echo "[6/9] Installation de Composer..."
if ! command -v composer >/dev/null 2>&1; then
  EXPECTED_CHECKSUM="$(curl -fsSL https://composer.github.io/installer.sig)"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

  if [[ "${EXPECTED_CHECKSUM}" != "${ACTUAL_CHECKSUM}" ]]; then
    echo "❌ Checksum Composer invalide."
    rm -f composer-setup.php
    exit 1
  fi

  php composer-setup.php --install-dir=/usr/local/bin --filename=composer
  rm -f composer-setup.php
fi

echo "  → $(composer --version)"

# ── 7. Répertoire de déploiement ──────────────────────────────────────────
echo "[7/9] Création du répertoire de déploiement..."
mkdir -p "${DEPLOY_PATH}/web/sites/default/files"
mkdir -p "${DEPLOY_PATH}/private"
mkdir -p "/var/backups/drupal"

chown -R www-data:www-data "${DEPLOY_PATH}"
find "${DEPLOY_PATH}" -type d -exec chmod 755 {} \;
find "${DEPLOY_PATH}" -type f -exec chmod 644 {} \;
chmod 775 "${DEPLOY_PATH}/web/sites/default/files"
chmod 770 "${DEPLOY_PATH}/private"

# ── 8. Utilisateur de déploiement ─────────────────────────────────────────
echo "[8/9] Création de l'utilisateur de déploiement..."
if ! id "${DEPLOY_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${DEPLOY_USER}"
fi

usermod -aG www-data "${DEPLOY_USER}"

mkdir -p "/home/${DEPLOY_USER}/.ssh"
touch "/home/${DEPLOY_USER}/.ssh/authorized_keys"
chmod 700 "/home/${DEPLOY_USER}/.ssh"
chmod 600 "/home/${DEPLOY_USER}/.ssh/authorized_keys"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "/home/${DEPLOY_USER}/.ssh"

cat > /etc/sudoers.d/drupal-deploy <<EOF
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl reload apache2
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl restart apache2
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/chown -R www-data\:www-data ${DEPLOY_PATH}
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/chmod -R 775 ${DEPLOY_PATH}/web/sites/default/files
EOF
chmod 0440 /etc/sudoers.d/drupal-deploy

# ── 9. VirtualHost Apache ─────────────────────────────────────────────────
echo "[9/9] Configuration du VirtualHost Apache..."

# Récupération de l'IP publique de la VM
SERVER_IP="$(curl -fsSL https://checkip.amazonaws.com || hostname -I | awk '{print $1}')"

cat > /etc/apache2/sites-available/drupal-crud.conf <<EOF
<VirtualHost *:80>
    ServerName ${SERVER_IP}
    ServerAdmin webmaster@localhost
    DocumentRoot ${DEPLOY_PATH}/web

    <Directory ${DEPLOY_PATH}/web>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/drupal-error.log
    CustomLog \${APACHE_LOG_DIR}/drupal-access.log combined
</VirtualHost>
EOF

a2ensite drupal-crud.conf
a2dissite 000-default.conf || true
apache2ctl configtest
systemctl reload apache2

# ── Résumé ────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Provisionnement terminé !"
echo ""
echo "  ⚠️  NOTER CES INFORMATIONS :"
echo "    DB_NAME = ${DB_NAME}"
echo "    DB_USER = ${DB_USER}"
echo "    DB_PASS = ${DB_PASS}"
echo "    IP VM   = ${SERVER_IP}"
echo ""
echo "  Prochaines étapes :"
echo "  1. Ajouter la clé SSH publique du runner GitHub dans :"
echo "     /home/${DEPLOY_USER}/.ssh/authorized_keys"
echo "  2. Créer le fichier settings.php de production dans :"
echo "     ${DEPLOY_PATH}/web/sites/default/settings.php"
echo "  3. Déployer le code et lancer l'installation Drupal"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"