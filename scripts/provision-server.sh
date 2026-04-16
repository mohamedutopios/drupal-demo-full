#!/usr/bin/env bash
# =============================================================================
#  provision-server.sh
#  Script de provisionnement initial de la VM Debian pour Drupal 10
#  Usage : sudo bash provision-server.sh
# =============================================================================

set -euo pipefail

# ── Variables à adapter ───────────────────────────────────────────────────
DEPLOY_USER="deploy"
DEPLOY_PATH="/var/www/drupal"
DB_NAME="drupal_prod"
DB_USER="drupal"
DB_PASS="$(openssl rand -base64 20)"
PHP_VERSION="8.2"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Provisionnement VM Debian — Drupal 10 + Apache"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 1. Mise à jour système ────────────────────────────────────────────────
echo "[1/9] Mise à jour des paquets..."
apt-get update -qq && apt-get upgrade -y -qq

# ── 2. Dépendances de base ────────────────────────────────────────────────
echo "[2/9] Installation des dépendances de base..."
apt-get install -y -qq \
  curl wget git unzip rsync \
  software-properties-common apt-transport-https ca-certificates \
  lsb-release gnupg2

# ── 3. PHP 8.2 via Sury ───────────────────────────────────────────────────
echo "[3/9] Installation de PHP ${PHP_VERSION}..."
curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg \
  https://packages.sury.org/php/apt.gpg
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] \
  https://packages.sury.org/php/ $(lsb_release -sc) main" \
  > /etc/apt/sources.list.d/php.list

apt-get update -qq
apt-get install -y -qq \
  php${PHP_VERSION} \
  php${PHP_VERSION}-cli \
  php${PHP_VERSION}-fpm \
  php${PHP_VERSION}-mysql \
  php${PHP_VERSION}-xml \
  php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-curl \
  php${PHP_VERSION}-gd \
  php${PHP_VERSION}-zip \
  php${PHP_VERSION}-intl \
  php${PHP_VERSION}-opcache \
  php${PHP_VERSION}-apcu

# PHP ini — production
PHP_INI="/etc/php/${PHP_VERSION}/apache2/php.ini"
sed -i 's/^memory_limit.*/memory_limit = 256M/'        "$PHP_INI"
sed -i 's/^upload_max_filesize.*/upload_max_filesize = 32M/' "$PHP_INI"
sed -i 's/^post_max_size.*/post_max_size = 32M/'        "$PHP_INI"
sed -i 's/^max_execution_time.*/max_execution_time = 120/' "$PHP_INI"
sed -i 's/^;date.timezone.*/date.timezone = Europe\/Paris/' "$PHP_INI"

# OPcache
cat >> "$PHP_INI" << 'EOF'
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=60
EOF

# ── 4. Apache ─────────────────────────────────────────────────────────────
echo "[4/9] Installation et configuration d'Apache..."
apt-get install -y -qq apache2 libapache2-mod-php${PHP_VERSION}
a2enmod rewrite headers expires deflate php${PHP_VERSION}

# ── 5. MySQL ──────────────────────────────────────────────────────────────
echo "[5/9] Installation de MySQL..."
apt-get install -y -qq mysql-server

mysql -uroot << SQL
  CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

  CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
    IDENTIFIED BY '${DB_PASS}';

  GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
  FLUSH PRIVILEGES;
SQL

echo "  → DB créée : ${DB_NAME} / utilisateur : ${DB_USER}"
echo "  → Mot de passe BDD généré (à stocker dans les secrets) :"
echo "     DB_PASS=${DB_PASS}"

# ── 6. Composer ───────────────────────────────────────────────────────────
echo "[6/9] Installation de Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# ── 7. Répertoire de déploiement ──────────────────────────────────────────
echo "[7/9] Création du répertoire de déploiement..."
mkdir -p "${DEPLOY_PATH}/web/sites/default/files"
mkdir -p "${DEPLOY_PATH}/private"
mkdir -p "/var/backups/drupal"

chown -R www-data:www-data "${DEPLOY_PATH}"
chmod -R 755 "${DEPLOY_PATH}"
chmod 775 "${DEPLOY_PATH}/web/sites/default/files"

# ── 8. Utilisateur de déploiement ─────────────────────────────────────────
echo "[8/9] Création de l'utilisateur de déploiement..."
if ! id "$DEPLOY_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
fi

mkdir -p "/home/${DEPLOY_USER}/.ssh"
chmod 700 "/home/${DEPLOY_USER}/.ssh"
touch "/home/${DEPLOY_USER}/.ssh/authorized_keys"
chmod 600 "/home/${DEPLOY_USER}/.ssh/authorized_keys"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "/home/${DEPLOY_USER}/.ssh"

# Sudo sans mdp pour les commandes de déploiement
cat > /etc/sudoers.d/drupal-deploy << EOF
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl reload apache2
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/chown -R www-data\:www-data /var/www/drupal*
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/chmod -R 775 /var/www/drupal*
EOF
chmod 0440 /etc/sudoers.d/drupal-deploy

# ── 9. VirtualHost Apache ─────────────────────────────────────────────────
echo "[9/9] Configuration du VirtualHost Apache..."
cat > /etc/apache2/sites-available/drupal-crud.conf << 'VHOST'
<VirtualHost *:80>
    ServerName   monsite.example.com
    DocumentRoot /var/www/drupal/web

    <Directory /var/www/drupal/web>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog  ${APACHE_LOG_DIR}/drupal-error.log
    CustomLog ${APACHE_LOG_DIR}/drupal-access.log combined
</VirtualHost>
VHOST

a2ensite drupal-crud
a2dissite 000-default
systemctl reload apache2

# ── Résumé ────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Provisionnement terminé !"
echo ""
echo "  Prochaines étapes :"
echo "  1. Ajouter la clé SSH publique du runner GitHub dans :"
echo "     /home/${DEPLOY_USER}/.ssh/authorized_keys"
echo ""
echo "  2. Copier scripts/settings.production.php vers :"
echo "     ${DEPLOY_PATH}/web/sites/default/settings.php"
echo "     (avec DB_PASS=${DB_PASS})"
echo ""
echo "  3. Configurer les secrets GitHub Actions :"
echo "     DEPLOY_HOST        = <IP de cette VM>"
echo "     DEPLOY_USER        = ${DEPLOY_USER}"
echo "     DEPLOY_SSH_PRIVATE_KEY = <clé privée SSH>"
echo "     DEPLOY_BASE_URL    = http://monsite.example.com"
echo ""
echo "  4. (Optionnel) Certificat SSL :"
echo "     apt install certbot python3-certbot-apache"
echo "     certbot --apache -d monsite.example.com"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
