# =============================================================================
#  Makefile — Drupal CRUD Project
#  Commandes pratiques pour le développement local avec Lando
# =============================================================================

.PHONY: help start stop install fresh-install cr cache-rebuild \
        test test-unit phpcs phpstan audit \
        db-export db-import login

# ── Couleurs ─────────────────────────────────────────────────────────────
CYAN   := \033[0;36m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RESET  := \033[0m

help: ## 📖 Affiche cette aide
	@echo ""
	@echo "$(CYAN)━━━ Drupal CRUD Project — Commandes disponibles ━━━$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(RESET) %s\n", $$1, $$2}'
	@echo ""

# ── Lando ─────────────────────────────────────────────────────────────────
start: ## 🟢 Démarrer Lando
	lando start

stop: ## 🔴 Arrêter Lando
	lando stop

rebuild: ## 🔄 Rebuilder Lando (après modif .lando.yml)
	lando rebuild -y

# ── Installation ─────────────────────────────────────────────────────────
install: ## 📦 Installer les dépendances et Drupal (première fois)
	lando composer install
	lando drush site:install standard \
		--db-url=mysql://drupal:drupal@database/drupal \
		--site-name="Drupal CRUD" \
		--account-name=admin \
		--account-pass=admin123 \
		--locale=fr \
		--yes
	lando drush pm:enable article_manager --yes
	lando drush cache:rebuild
	@echo "$(GREEN)✅ Installation terminée !$(RESET)"
	@echo "   URL     : https://drupal-crud.lndo.site"
	@echo "   Admin   : admin / admin123"
	@echo "   Articles: https://drupal-crud.lndo.site/articles"

fresh-install: stop ## 🔥 Réinstallation complète (supprime la BDD)
	lando start
	$(MAKE) install

# ── Drush / Cache ─────────────────────────────────────────────────────────
cr: ## ♻️  Rebuild du cache Drupal
	lando drush cache:rebuild

cache-rebuild: cr

login: ## 🔑 Générer un lien de connexion admin
	lando drush user:login --uri=https://drupal-crud.lndo.site

module-enable: ## 🔌 Activer article_manager (usage: make module-enable)
	lando drush pm:enable article_manager --yes
	lando drush cache:rebuild

# ── Base de données ───────────────────────────────────────────────────────
db-export: ## 💾 Exporter la BDD dans dumps/drupal-$(date).sql
	@mkdir -p dumps
	lando drush sql:dump --gzip > dumps/drupal-$$(date +%Y%m%d_%H%M%S).sql.gz
	@echo "$(GREEN)✅ Export BDD terminé$(RESET)"

db-import: ## 📥 Importer un dump SQL (usage: make db-import FILE=dumps/xxx.sql)
	@if [ -z "$(FILE)" ]; then \
		echo "$(YELLOW)Usage: make db-import FILE=dumps/mon-dump.sql$(RESET)"; exit 1; \
	fi
	lando db-import $(FILE)
	lando drush cache:rebuild

# ── Qualité de code ───────────────────────────────────────────────────────
phpcs: ## 🔍 Lancer PHP CodeSniffer (Drupal standards)
	lando phpcs \
		--standard=Drupal,DrupalPractice \
		--extensions=php,module,inc,install \
		web/modules/custom/

phpcs-fix: ## 🛠️  Corriger automatiquement les erreurs PHPCS
	lando ./vendor/bin/phpcbf \
		--standard=Drupal,DrupalPractice \
		--extensions=php,module,inc,install \
		web/modules/custom/

phpstan: ## 🔬 Lancer PHPStan (analyse statique)
	lando ./vendor/bin/phpstan analyse \
		--configuration=phpstan.neon \
		--memory-limit=512M

test: ## 🧪 Lancer tous les tests PHPUnit
	lando phpunit --configuration=phpunit.xml.dist

test-unit: ## 🧪 Tests unitaires uniquement
	lando phpunit --configuration=phpunit.xml.dist --testsuite=unit

audit: ## 🛡️  Audit de sécurité Composer
	lando composer audit

# ── Utilitaires ───────────────────────────────────────────────────────────
status: ## 📊 Statut Drupal et modules
	lando drush status
	lando drush pm:list --type=module --status=enabled --no-core

config-export: ## ⚙️  Exporter la configuration
	lando drush config:export --yes
	@echo "$(GREEN)✅ Config exportée dans config/sync/$(RESET)"

config-import: ## ⚙️  Importer la configuration
	lando drush config:import --yes

info: ## ℹ️  Afficher les URLs Lando
	@echo "$(CYAN)━━━ Accès Lando ━━━$(RESET)"
	@echo "  Drupal   : https://drupal-crud.lndo.site"
	@echo "  Mailhog  : http://mail.drupal-crud.lndo.site:8025"
	@echo "  Articles : https://drupal-crud.lndo.site/articles"
	@echo "  MySQL    : 127.0.0.1:3307 (drupal/drupal)"
