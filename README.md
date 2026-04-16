# Drupal CRUD — Article Manager

Projet Drupal 10 avec un module CRUD custom (`article_manager`) tournant
localement via **Lando** et déployé automatiquement sur une **VM Debian / Apache / MySQL**
via **GitHub Actions**.

---

## 🗂️ Structure du projet

```
drupal-crud-project/
├── .github/
│   └── workflows/
│       └── drupal-deploy.yml        # Pipeline CI/CD complète
├── web/
│   ├── modules/
│   │   └── custom/
│   │       └── article_manager/     # Module CRUD custom
│   │           ├── src/
│   │           │   ├── Controller/
│   │           │   │   └── ArticleController.php   # Liste + détail
│   │           │   └── Form/
│   │           │       ├── ArticleForm.php          # Création / modification
│   │           │       └── ArticleDeleteForm.php    # Suppression confirmée
│   │           ├── templates/
│   │           │   └── article-manager-detail.html.twig
│   │           ├── css/
│   │           │   └── article_manager.css
│   │           ├── tests/src/Unit/
│   │           │   └── ArticleValidationTest.php
│   │           ├── article_manager.info.yml
│   │           ├── article_manager.routing.yml
│   │           ├── article_manager.permissions.yml
│   │           ├── article_manager.libraries.yml
│   │           ├── article_manager.links.menu.yml
│   │           ├── article_manager.module
│   │           └── article_manager.install
│   └── sites/
│       └── default/
│           ├── settings.php          # Config locale Lando
│           └── settings.local.php   # Cache désactivé en dev
├── config/sync/                      # Configuration Drupal exportée
├── scripts/
│   ├── provision-server.sh          # Provisionnement VM Debian
│   ├── apache-vhost.conf            # VirtualHost Apache
│   └── settings.production.php     # Settings production (ne pas commiter)
├── drush/
│   └── sites/self.site.yml          # Alias Drush local / prod
├── .lando.yml                        # Configuration Lando
├── .phpcs.xml                        # Standards PHPCS
├── phpstan.neon                      # Config PHPStan
├── phpunit.xml.dist                  # Config PHPUnit
├── Makefile                          # Commandes pratiques
└── composer.json
```

---

## 🚀 Démarrage local avec Lando

### Prérequis

- [Lando](https://lando.dev/download/) ≥ 3.21
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

### Installation en une commande

```bash
# Cloner le dépôt
git clone https://github.com/TON_ORG/drupal-crud.git
cd drupal-crud

# Installation complète (Composer + Drupal + module)
make install
```

Accès :

| Service   | URL                                        |
|-----------|--------------------------------------------|
| Drupal    | https://drupal-crud.lndo.site              |
| Admin     | https://drupal-crud.lndo.site/user/login   |
| Articles  | https://drupal-crud.lndo.site/articles     |
| Mailhog   | http://mail.drupal-crud.lndo.site:8025     |
| MySQL     | `127.0.0.1:3307` — drupal / drupal         |

Identifiants admin : `admin` / `admin123`

---

## 📋 Module Article Manager — Fonctionnalités CRUD

| Route                        | Action              | Permission requise  |
|------------------------------|---------------------|---------------------|
| `/articles`                  | Liste paginée       | `access article manager` |
| `/articles/new`              | Créer un article    | `manage articles`   |
| `/articles/{id}`             | Voir un article     | `access article manager` |
| `/articles/{id}/edit`        | Modifier un article | `manage articles`   |
| `/articles/{id}/delete`      | Supprimer (confirm) | `manage articles`   |

### Champs de l'entité Article

| Champ        | Type       | Description                         |
|--------------|------------|-------------------------------------|
| `id`         | serial     | Clé primaire auto-incrémentée       |
| `title`      | varchar(255)| Titre (obligatoire, 3–255 chars)   |
| `body`       | text       | Corps de l'article                  |
| `category`   | varchar    | actualite / tutoriel / annonce / autre |
| `status`     | tinyint    | 1 = Publié, 0 = Brouillon          |
| `author_uid` | int        | UID de l'auteur                     |
| `created`    | int        | Timestamp de création               |
| `updated`    | int        | Timestamp de modification           |

---

## 🔧 Commandes Makefile

```bash
make help           # Afficher toutes les commandes
make start          # Démarrer Lando
make stop           # Arrêter Lando
make install        # Installation complète
make cr             # Rebuild du cache
make login          # Lien de connexion admin
make test           # Lancer les tests PHPUnit
make test-unit      # Tests unitaires uniquement
make phpcs          # PHP CodeSniffer
make phpcs-fix      # Correction auto PHPCS
make phpstan        # Analyse statique
make audit          # Audit sécurité Composer
make db-export      # Exporter la BDD
make config-export  # Exporter la config Drupal
```

---

## 🔁 Pipeline GitHub Actions

La pipeline se déclenche à chaque **push sur `main`** ou **`develop`**.

```
code-quality ──┬── tests ──────────┬──► build-assets ──► deploy ──► notify
               └── security-audit ─┘
```

### Jobs

| Job             | Description                                         |
|-----------------|-----------------------------------------------------|
| `code-quality`  | PHPCS (Drupal Standards) + PHPStan niveau 6         |
| `tests`         | PHPUnit unit + kernel avec MySQL service            |
| `security-audit`| Composer Audit, Drush advisories, Gitleaks, Semgrep, Trivy |
| `build-assets`  | Build thème + Composer prod + tarball               |
| `deploy`        | Backup BDD → rsync → updatedb → config:import → reload Apache |
| `notify`        | Slack succès/échec                                  |

### Secrets GitHub à configurer

```
Settings → Secrets and variables → Actions → New repository secret
```

| Secret                    | Description                              |
|---------------------------|------------------------------------------|
| `DEPLOY_SSH_PRIVATE_KEY`  | Clé privée SSH (ed25519)                 |
| `DEPLOY_HOST`             | IP ou FQDN de la VM                      |
| `DEPLOY_USER`             | Utilisateur SSH (ex: `deploy`)           |
| `SLACK_WEBHOOK_URL`       | (Optionnel) Webhook Slack                |

### Variables GitHub

```
Settings → Secrets and variables → Actions → Variables
```

| Variable          | Exemple                      |
|-------------------|------------------------------|
| `DEPLOY_BASE_URL` | `http://monsite.example.com` |
| `DEPLOY_SSH_PORT` | `22`                         |

---

## 🖥️ Provisionnement du serveur Debian

```bash
# Sur la VM Debian (en root)
bash scripts/provision-server.sh
```

Le script installe et configure automatiquement :
- PHP 8.2 (Sury) + extensions Drupal
- Apache 2 + mod_rewrite
- MySQL 8 + base de données `drupal_prod`
- Utilisateur `deploy` avec droits sudo limités
- VirtualHost Apache

### Configuration post-provisionnement

```bash
# 1. Ajouter la clé publique du runner GitHub Actions
echo "ssh-ed25519 AAAA..." >> /home/deploy/.ssh/authorized_keys

# 2. Copier et adapter le settings.php de production
cp scripts/settings.production.php /var/www/drupal/web/sites/default/settings.php
# → Éditer DB_NAME, DB_USER, DB_PASS, hash_salt, trusted_host_patterns

# 3. Premier déploiement manuel
cd /var/www/drupal
composer install --no-dev --optimize-autoloader
vendor/bin/drush site:install --yes
vendor/bin/drush pm:enable article_manager --yes
```

### SSL avec Let's Encrypt (optionnel)

```bash
apt install certbot python3-certbot-apache
certbot --apache -d monsite.example.com
```

---

## 🧪 Tests

```bash
# Localement via Lando
make test-unit

# Ou directement
lando phpunit --configuration=phpunit.xml.dist --testsuite=unit
```

Les tests sont dans `web/modules/custom/article_manager/tests/src/Unit/`.

---

## 📁 Notes importantes

- Le fichier `web/sites/default/settings.php` **n'est pas commité** (gitignore).  
  Il est géré séparément pour chaque environnement.
- Le répertoire `web/sites/default/files/` (uploads) est **exclu du déploiement**.  
  Il persiste sur le serveur entre les déploiements.
- La configuration Drupal (`config/sync/`) **est commitée** pour garantir la cohérence entre environments.
