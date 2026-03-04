# ═══════════════════════════════════════════════════════════════════════════════
#                        SWU RSS News - Makefile
#              Cross-platform: Linux, macOS, Windows (WSL/Git Bash)
# ═══════════════════════════════════════════════════════════════════════════════

.DEFAULT_GOAL := help

# ╔═══════════════════════════════════════════════════════════╗
# ║                      CONFIGURATION                        ║
# ╚═══════════════════════════════════════════════════════════╝

# Project Settings
PROJECT_NAME := swu-rssnews
COMPOSE_PROFILES := --profile setup --profile migration
DATABASE_NAME := RSSActivityWeb

# Service Names (ตรงกับ docker-compose.yml)
SERVICE_ASPNETCORE := aspdotnetweb
SERVICE_DB := mssql
SERVICE_FRONTEND := frontend
SERVICE_NGINX := web-server

# Timeout Settings (seconds)
TIMEOUT_DB := 60
TIMEOUT_GRAPHQL := 90
TIMEOUT_HEALTH := 180

# Directory Structure
DIR_DATABASE := ./database
DIR_FRONTEND := ./vite-ui
DIR_ASPNETCORE := ./aspnetcore
DIR_SCRIPTS := ./scripts
DIR_SECRETS := ./secrets
DIR_APOLLO := $(DIR_FRONTEND)/apollo
DIR_MIGRATIONS := ./aspnetcore/Migrations
DIR_BACKUPS := ./backups

# Important Files
FILE_PASSWORD := $(DIR_SECRETS)/db_password.txt
FILE_SCHEMA := $(DIR_APOLLO)/schema.graphql

# Migration Scripts
SCRIPT_ADD_FIRST := $(DIR_ASPNETCORE)/add-first-migration.sh
SCRIPT_ADD_MIGRATION := $(DIR_ASPNETCORE)/add-migration.sh
SCRIPT_QUICK_FIX := $(DIR_ASPNETCORE)/quick-fix.sh

# Terminal Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
BLUE   := \033[0;34m
CYAN   := \033[0;36m
GRAY   := \033[0;90m
NC     := \033[0m

# OS Detection and Commands
UNAME_S := $(shell uname -s 2>/dev/null || echo Windows)
ifeq ($(UNAME_S),Darwin)
    SED_INPLACE := sed -i ''
    OPEN_CMD := open
else ifeq ($(UNAME_S),Linux)
    SED_INPLACE := sed -i
    OPEN_CMD := xdg-open
else
    SED_INPLACE := sed -i
    OPEN_CMD := start
endif

# ╔═══════════════════════════════════════════════════════════╗
# ║                   PROJECT INITIALIZATION                  ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: init init-project project-setup

init: init-project
init-project:
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)              Project Initialization                       $(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@if [ ! -f "./init-project.sh" ]; then \
        echo "$(RED)❌ init-project.sh not found$(NC)"; \
        exit 1; \
    fi
	@chmod +x ./init-project.sh
	@if command -v dos2unix >/dev/null 2>&1; then \
        dos2unix ./init-project.sh 2>/dev/null || true; \
    fi
	@bash ./init-project.sh

project-setup: init-project


# ╔═══════════════════════════════════════════════════════════╗
# ║                         HELP                              ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: help
help:
	@echo ""
	@echo "$(BLUE)╔═══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║       SWU RSS News - Docker Management Commands           ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(CYAN)📦 QUICK START$(NC)"
	@echo "  $(GREEN)make init$(NC)                - เริ่มต้นโปรเจ็กต์"
	@echo "  $(GREEN)make first-run$(NC)           - ติดตั้งและรันโปรเจ็กต์ครั้งแรก"
	@echo "  $(GREEN)make dev$(NC)                 - รัน development mode"
	@echo "  $(GREEN)make prod$(NC)                - รัน production mode"
	@echo "  $(GREEN)make stop$(NC)                - หยุด services"
	@echo "  $(GREEN)make restart$(NC)             - Restart services"
	@echo ""
	@echo "$(CYAN)🔧 CONFIGURATION$(NC)"
	@echo "  $(GREEN)make check-app-url$(NC)       - ตรวจสอบ APP_URL"
	@echo "  $(GREEN)make assign-app-url$(NC)      - ตั้งค่า APP_URL"
	@echo "  $(GREEN)make show-env$(NC)            - แสดง environment config"
	@echo "  $(GREEN)make test-app-url$(NC)        - ทดสอบ APP_URL"
	@echo ""
	@echo "$(CYAN)🐳 DOCKER$(NC)"
	@echo "  $(GREEN)make build$(NC)               - Build all containers"
	@echo "  $(GREEN)make build-no-cache$(NC)      - Build without cache"
	@echo "  $(GREEN)make up$(NC)                  - Start services"
	@echo "  $(GREEN)make down$(NC)                - Stop services"
	@echo "  $(GREEN)make logs$(NC)                - View all logs"
	@echo "  $(GREEN)make status$(NC)              - Show container status"
	@echo ""
	@echo "$(CYAN)🎨 FRONTEND$(NC)"
	@echo "  $(GREEN)make frontend-build$(NC)      - Build frontend container"
	@echo "  $(GREEN)make frontend-logs$(NC)       - ดู frontend logs"
	@echo "  $(GREEN)make frontend-shell$(NC)      - เข้า frontend shell"
	@echo "  $(GREEN)make frontend-restart$(NC)    - Restart frontend"
	@echo ""
	@echo "$(CYAN)🔮 GRAPHQL$(NC)"
	@echo "  $(GREEN)make graphql-setup$(NC)       - Complete GraphQL setup"
	@echo "  $(GREEN)make graphql-generate$(NC)    - สร้าง GraphQL client"
	@echo "  $(GREEN)make graphql-test$(NC)        - ทดสอบ GraphQL endpoint"
	@echo "  $(GREEN)make graphql-check$(NC)       - Check schema status"
	@echo "  $(GREEN)make graphql-reset$(NC)       - Reset GraphQL files"
	@echo ""
	@echo "$(CYAN)🐛 GRAPHQL DEBUG$(NC)"
	@echo "  $(GREEN)make graphql-status$(NC)      - สรุปสถานะแบบเร็ว"
	@echo "  $(GREEN)make graphql-clean$(NC)       - ล้าง generated files"
	@echo "  $(GREEN)make graphql-health$(NC)      - ทดสอบ health endpoint"
	@echo ""
	@echo "$(CYAN)🗄️  DATABASE$(NC)"
	@echo "  $(GREEN)make db-setup$(NC)            - ติดตั้งฐานข้อมูล"
	@echo "  $(GREEN)make db-shell$(NC)            - Open SQL shell"
	@echo "  $(GREEN)make db-test$(NC)             - ทดสอบการเชื่อมต่อฐานข้อมูล"
	@echo "  $(GREEN)make db-migrate NAME=x$(NC)   - Create migration"
	@echo "  $(GREEN)make db-backup$(NC)           - Backup database"
	@echo ""
	@echo "$(CYAN)💾 VOLUMES$(NC)"
	@echo "  $(GREEN)make volumes-init$(NC)        - Initialize SQL volumes"
	@echo "  $(GREEN)make volumes-check$(NC)       - Check permissions"
	@echo "  $(GREEN)make volumes-fix$(NC)         - Fix permissions"
	@echo "  $(GREEN)make volumes-list$(NC)        - List project volumes"
	@echo ""
	@echo "$(CYAN)🏥 HEALTH & STATUS$(NC)"
	@echo "  $(GREEN)make health$(NC)              - Quick health check"
	@echo "  $(GREEN)make health-full$(NC)         - Detailed health report"
	@echo "  $(GREEN)make urls$(NC)                - Show service URLs"
	@echo "  $(GREEN)make quick$(NC)               - Quick system check"
	@echo ""
	@echo "$(CYAN)🧹 MAINTENANCE$(NC)"
	@echo "  $(GREEN)make clean$(NC)               - ลบ containers"
	@echo "  $(GREEN)make rebuild$(NC)             - Rebuild everything"
	@echo "  $(GREEN)make reset$(NC)               - Full reset (⚠️ destructive)"
	@echo "  $(GREEN)make fix-line-endings$(NC)    - Fix line endings"
	@echo ""
	@echo "$(CYAN)🪟 WINDOWS$(NC)"
	@echo "  $(GREEN)make windows-quick-start$(NC) - Windows quick start"
	@echo "  $(GREEN)make windows-fix-line-endings$(NC) - Fix line endings (PowerShell)"
	@echo ""
	@echo "$(GRAY)For more commands: make help-all$(NC)"
	@echo ""

.PHONY: help-all
help-all: help
	@echo "$(CYAN)📋 ALL COMMANDS$(NC)"
	@echo ""
	@echo "$(YELLOW)Installation:$(NC)"
	@echo "   make create-password          - Create database password"
	@echo "   make setup-scripts            - Setup script permissions"
	@echo "   make install                  - Install database"
	@echo ""
	@echo "$(YELLOW)GraphQL Advanced:$(NC)"
	@echo "   make graphql-download         - Download schema"
	@echo "   make graphql-watch            - Watch mode for codegen"
	@echo "   make graphql-validate         - Validate schema"
	@echo "   make graphql-info             - Show GraphQL config"
	@echo ""
	@echo "$(YELLOW)Database Advanced:$(NC)"
	@echo "   make db-debug                 - Debug SQL Server"
	@echo "   make db-logs                  - View SQL logs"
	@echo "   make db-size                  - Show database size"
	@echo "   make db-restore               - Restore from backup"
	@echo ""
	@echo "$(YELLOW)EF Core Migrations Advanced:$(NC)"
	@echo "   make migration-rollback       - Rollback last migration"
	@echo "   make migration-remove         - Remove last migration"
	@echo "   make migration-script         - Generate SQL script"
	@echo "   make migration-clean          - Clean migration folder"
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@echo "   make npm-install              - Install npm packages"
	@echo "   make npm-update               - Update npm packages"
	@echo "   make type-check               - TypeScript check"
	@echo "   make lint                     - Run linter"
	@echo "   make test                     - Run tests"
	@echo ""
	@echo "$(YELLOW)SSH Management:$(NC)"
	@echo "   make ssh-start                - Start SSH server"
	@echo "   make ssh-stop                 - Stop SSH server"
	@echo "   make ssh-status               - Show SSH status"
	@echo "   make ssh-help                 - SSH help"
	@echo ""

# ╔═══════════════════════════════════════════════════════════╗
# ║                EF CORE MIGRATIONS SECTION                 ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: migration-first migration-add migration-apply migration-fix
.PHONY: migration-status migration-list migration-rollback migration-remove
.PHONY: migration-script migration-clean migration-help migration-begin

# ════════════════════════════════════════════════════════════
# 🆕 ตรวจสอบว่าเป็น migration ครั้งแรกหรือไม่
# ════════════════════════════════════════════════════════════
define is_first_migration
$(shell \
    if [ ! -d "$(DIR_MIGRATIONS)" ]; then \
        echo "true"; \
    elif [ -z "$$(find $(DIR_MIGRATIONS) -name '*.cs' 2>/dev/null)" ]; then \
        echo "true"; \
    else \
        echo "false"; \
    fi \
)
endef

# ════════════════════════════════════════════════════════════
# 🆕 สร้างไดเรกทอรี Migrations (เฉพาะครั้งแรก)
# ════════════════════════════════════════════════════════════
migration-begin:
	@echo "$(CYAN)📁 Checking Migrations directory...$(NC)"
	@if [ "$(call is_first_migration)" = "true" ]; then \
        echo "$(YELLOW)🆕 First migration detected$(NC)"; \
        if [ ! -d "$(DIR_MIGRATIONS)" ]; then \
            mkdir -p $(DIR_MIGRATIONS); \
            echo "$(GREEN)✅ Created: $(DIR_MIGRATIONS)$(NC)"; \
        else \
            echo "$(GREEN)✅ Directory exists (empty): $(DIR_MIGRATIONS)$(NC)"; \
        fi; \
    else \
        echo "$(GREEN)✅ Migrations already exist$(NC)"; \
        ls -1 $(DIR_MIGRATIONS)/*.cs 2>/dev/null | wc -l | xargs -I {} echo "   Found {} migration file(s)"; \
    fi

# สร้าง initial migration (ใช้ครั้งแรก)
migration-first: migration-begin
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)            Creating Initial EF Core Migration             $(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 1: Building migration image...$(NC)"
	@docker compose build --target migration migration-db
	@echo ""
	@echo "$(YELLOW)Step 2: Creating migration...$(NC)"
	@docker compose $(COMPOSE_PROFILES) up migration-db
	@echo "$(GREEN)✅ Initial migration complete$(NC)"

# สร้าง migration ใหม่ (ใช้งานปกติ)
migration-add: migration-begin
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)               Creating New EF Core Migration              $(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@MIGRATION_NAME_FINAL=""; \
	if [ "$(call is_first_migration)" = "true" ]; then \
	    MIGRATION_NAME_FINAL="InitialCreate"; \
	elif [ -z "$(NAME)" ]; then \
	    echo "$(RED)❌ Please provide migration name$(NC)"; \
	    exit 1; \
	else \
	    MIGRATION_NAME_FINAL="$(NAME)"; \
	fi; \
	echo "$(YELLOW)📦 Creating migration: $$MIGRATION_NAME_FINAL$(NC)"; \
	echo ""; \
	echo "$(YELLOW)Building migration image...$(NC)"; \
	docker compose build migration-db; \
	if [ -f .env ]; then \
	    $(SED_INPLACE) 's/^ADD_NEW_MIGRATION=.*/ADD_NEW_MIGRATION=true/' .env || \
	    echo "ADD_NEW_MIGRATION=true" >> .env; \
	    $(SED_INPLACE) "s/^MIGRATION_NAME=.*/MIGRATION_NAME=$$MIGRATION_NAME_FINAL/" .env || \
	    echo "MIGRATION_NAME=$$MIGRATION_NAME_FINAL" >> .env; \
	fi; \
	docker compose --profile migration up migration-db; \
	echo ""; \
	echo "$(GREEN)✅ Migration '$$MIGRATION_NAME_FINAL' created and applied$(NC)"
	@$(MAKE) migration-list
	@if [ -f .env ]; then \
	    $(SED_INPLACE) 's/^ADD_NEW_MIGRATION=true/ADD_NEW_MIGRATION=false/' .env; \
	    echo "$(GRAY)ℹ️  Reset ADD_NEW_MIGRATION=false$(NC)"; \
	fi

# Apply migrations ที่มีอยู่แล้ว
migration-apply:
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)              Applying Database Migrations                 $(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if [ "$(call is_first_migration)" = "true" ]; then \
        echo "$(RED)❌ No migrations found to apply$(NC)"; \
        echo ""; \
        echo "$(YELLOW)💡 Create migrations first:$(NC)"; \
        echo "   $(GREEN)make migration-first$(NC)  - For initial setup"; \
        echo "   $(GREEN)make migration-add NAME=xxx$(NC)  - For new migration"; \
        exit 1; \
    fi
	@if [ -f .env ]; then \
		echo "ADD_NEW_MIGRATION=false" > .env.tmp; \
		cat .env | grep -v "^ADD_NEW_MIGRATION=" | grep -v "^MIGRATION_NAME=" >> .env.tmp; \
		mv .env.tmp .env; \
	fi
	@docker exec $(SERVICE_ASPNETCORE) /usr/local/bin/add-migration.sh
	@echo "$(GREEN)✅ Migrations applied successfully$(NC)"

# Quick fix สำหรับปัญหา migration
migration-fix: migration-begin
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)           Quick Fix - EF Core Migration Problem          $(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if [ ! -f "$(SCRIPT_QUICK_FIX)" ]; then \
		echo "$(RED)❌ Script not found: $(SCRIPT_QUICK_FIX)$(NC)"; \
		exit 1; \
	fi
	@chmod +x $(SCRIPT_QUICK_FIX)
	@bash $(SCRIPT_QUICK_FIX)

# ตรวจสอบสถานะ migrations
migration-status:
	@echo "$(CYAN)🔍 Checking Migration Status$(NC)"
	@echo "════════════════════════════════════════════════════════════"
	@echo ""
	@echo "$(YELLOW)📁 Migration Directory:$(NC)"
	@if [ "$(call is_first_migration)" = "true" ]; then \
        echo "  $(YELLOW)🆕 No migrations yet (first-time setup needed)$(NC)"; \
        if [ ! -d "$(DIR_MIGRATIONS)" ]; then \
            echo "  $(GRAY)Directory does not exist$(NC)"; \
        else \
            echo "  $(GRAY)Directory exists but empty$(NC)"; \
        fi; \
    else \
        echo "  $(GREEN)✅ Migrations exist$(NC)"; \
        ls -lh $(DIR_MIGRATIONS)/*.cs 2>/dev/null | wc -l | xargs -I {} echo "  Found {} migration file(s)"; \
    fi
	@echo ""
	@echo "$(YELLOW)🗄️  Database Migrations:$(NC)"
	@docker exec $(SERVICE_ASPNETCORE) bash -c "cd /app/aspnetcore && \
        dotnet ef migrations list --context RSSNewsDbContext 2>/dev/null" || \
        echo "  $(YELLOW)⚠️  Cannot retrieve database migrations$(NC)"
	@echo ""
	@echo "$(YELLOW)📊 Current Environment:$(NC)"
	@if [ -f .env ]; then \
        grep -E "^(ADD_NEW_MIGRATION|MIGRATION_NAME)=" .env || echo "  No migration variables set"; \
    fi
	@echo ""
	@echo "$(YELLOW)💡 Quick Actions:$(NC)"
	@if [ "$(call is_first_migration)" = "true" ]; then \
        echo "  $(GREEN)make migration-first$(NC)  - Create initial migration"; \
    else \
        echo "  $(GREEN)make migration-add NAME=xxx$(NC)  - Add new migration"; \
        echo "  $(GREEN)make migration-apply$(NC)  - Apply pending migrations"; \
    fi

# แสดงรายการ migration files
migration-list:
	@echo "$(CYAN)📄 Migration Files$(NC)"
	@echo "════════════════════════════════════════════════════════════"
	@if [ "$(call is_first_migration)" = "true" ]; then \
        echo "  $(YELLOW)🆕 No migration files yet$(NC)"; \
        echo ""; \
        echo "  $(CYAN)💡 Create your first migration:$(NC)"; \
        echo "     $(GREEN)make migration-first$(NC)"; \
    else \
        echo ""; \
        ls -lh $(DIR_MIGRATIONS)/*.cs 2>/dev/null | \
        awk '{printf "  📄 %s  %s  %s\n", $$6" "$$7, $$5, $$9}' || \
        echo "  $(YELLOW)No migration files found$(NC)"; \
        echo ""; \
        echo "  $(GRAY)Total: $$(ls -1 $(DIR_MIGRATIONS)/*.cs 2>/dev/null | wc -l) file(s)$(NC)"; \
    fi

# Rollback migration (ย้อนกลับ)
migration-rollback:
	@if [ "$(call is_first_migration)" = "true" ]; then \
        echo "$(RED)❌ No migrations to rollback$(NC)"; \
        exit 1; \
    fi
	@echo "$(YELLOW)⚠️  Rolling back to previous migration...$(NC)"
	@docker exec $(SERVICE_ASPNETCORE) bash -c "cd /app/aspnetcore && \
        dotnet ef database update 0 --context RSSNewsDbContext"
	@echo "$(GREEN)✅ Database rolled back$(NC)"

# ลบ migration ล่าสุด
migration-remove:
	@if [ "$(call is_first_migration)" = "true" ]; then \
        echo "$(RED)❌ No migrations to remove$(NC)"; \
        exit 1; \
    fi
	@echo "$(YELLOW)🗑️  Removing last migration...$(NC)"
	@docker exec $(SERVICE_ASPNETCORE) bash -c "cd /app/aspnetcore && \
        dotnet ef migrations remove --context RSSNewsDbContext --force"
	@echo "$(GREEN)✅ Last migration removed$(NC)"
	@$(MAKE) migration-list

# สร้าง SQL script จาก migrations
migration-script:
	@if [ "$(call is_first_migration)" = "true" ]; then \
        echo "$(RED)❌ No migrations to generate script from$(NC)"; \
        exit 1; \
    fi
	@echo "$(CYAN)📝 Generating SQL Migration Script$(NC)"
	@docker exec $(SERVICE_ASPNETCORE) bash -c "cd /app/aspnetcore && \
        dotnet ef migrations script --context RSSNewsDbContext --output /tmp/migration.sql"
	@docker cp $(SERVICE_ASPNETCORE):/tmp/migration.sql ./migration.sql
	@echo "$(GREEN)✅ SQL script saved to: migration.sql$(NC)"

# ลบ migrations ทั้งหมด
migration-clean:
	@echo "$(RED)⚠️  WARNING: This will delete ALL migration files$(NC)"
	@if [ -d "$(DIR_MIGRATIONS)" ]; then \
        echo ""; \
        echo "$(YELLOW)Files to be deleted:$(NC)"; \
        ls -1 $(DIR_MIGRATIONS)/*.cs 2>/dev/null || echo "  (none)"; \
        echo ""; \
    fi
	@read -p "Are you sure? (type 'yes' to confirm): " confirm; \
    if [ "$$confirm" = "yes" ]; then \
        rm -rf $(DIR_MIGRATIONS); \
        echo "$(GREEN)✅ Migration folder cleaned$(NC)"; \
        echo "$(YELLOW)💡 Run 'make migration-first' to create new initial migration$(NC)"; \
    else \
        echo "$(YELLOW)Cancelled$(NC)"; \
    fi

# แสดงวิธีใช้งาน migrations
migration-help:
	@echo "$(CYAN)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)              EF Core Migrations - Help Guide              $(NC)"
	@echo "$(CYAN)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)🚀 Quick Start:$(NC)"
	@if [ "$(call is_first_migration)" = "true" ]; then \
        echo "  $(GREEN)→ You need to create your first migration:$(NC)"; \
        echo "     $(GREEN)make migration-first$(NC)"; \
    else \
        echo "  $(GREEN)✓ Migrations already exist$(NC)"; \
    fi
	@echo ""
	@echo "$(YELLOW)📦 Creating Migrations:$(NC)"
	@echo "  $(GREEN)make migration-first$(NC)      - First time project setup"
	@echo "  $(GREEN)make migration-add$(NC)        - Add new EF Core migration"
	@echo ""
	@echo "$(YELLOW)🔄 Applying Migrations:$(NC)"
	@echo "  $(GREEN)make migration-apply$(NC)      - Apply pending migrations"
	@echo ""
	@echo "$(YELLOW)📋 Status & Info:$(NC)"
	@echo "  $(GREEN)make migration-status$(NC)     - Check migration status"
	@echo "  $(GREEN)make migration-list$(NC)       - List migration files"
	@echo ""
	@echo "$(YELLOW)🔧 Management:$(NC)"
	@echo "  $(GREEN)make migration-rollback$(NC)   - Rollback all migrations"
	@echo "  $(GREEN)make migration-remove$(NC)     - Remove last migration"
	@echo "  $(GREEN)make migration-script$(NC)     - Generate SQL script"
	@echo ""
	@echo "$(YELLOW)🆘 Troubleshooting:$(NC)"
	@echo "  $(GREEN)make migration-fix$(NC)        - Quick fix for problems"
	@echo "  $(GREEN)make migration-clean$(NC)      - Delete all migrations"
	@echo ""
	@echo "$(YELLOW)💡 Environment Variables (.env):$(NC)"
	@echo "  ADD_NEW_MIGRATION=true    - Enable migration creation"
	@echo "  MIGRATION_NAME=YourName   - Set migration name"
	@echo ""
	@echo "$(YELLOW)📁 Directory:$(NC)"
	@echo "  $(DIR_MIGRATIONS)"
	@echo ""

# ╔═══════════════════════════════════════════════════════════╗
# ║                     QUICK START                           ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: first-run
first-run:
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)                   First Time Setup                        $(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 1: Initializing project...$(NC)"
	@$(MAKE) init-project
	@echo ""
	@$(MAKE) check-app-url
	@read -p "Continue with setup? (Y/n): " confirm; \
	[ "$$confirm" != "n" ] || exit 1
	@[ -f "$(FILE_PASSWORD)" ] || $(MAKE) create-password
	@echo "$(YELLOW)🧹 Cleaning previous setup...$(NC)"
	@docker compose $(COMPOSE_PROFILES) down -v 2>/dev/null || true
	@echo "$(YELLOW)📁 Initializing volumes...$(NC)"
	@$(MAKE) volumes-init
	@echo "$(YELLOW)🏗️  Building containers...$(NC)"
	@$(MAKE) build
	@echo "$(YELLOW)💾 Setting up database...$(NC)"
	@$(MAKE) install
	@echo "$(YELLOW)🔄 Creating initial migration...$(NC)"
	@echo "$(YELLOW)Step 4: Setting up migrations...$(NC)"
	@if [ "$$($(MAKE) -s check-first-migration)" = "true" ]; then \
        echo "$(CYAN)Creating initial migration...$(NC)"; \
        $(MAKE) migration-add || echo "$(YELLOW)⚠️  Migration setup incomplete$(NC)"; \
    else \
        echo "$(GREEN)✓ Migrations already exist$(NC)"; \
        $(MAKE) migration-apply || echo "$(YELLOW)⚠️  Migration apply incomplete$(NC)"; \
    fi
	@echo ""
	@echo "$(YELLOW)🚀 Starting services...$(NC)"
	@docker compose up -d
	@$(MAKE) wait-health
	@echo "$(YELLOW)🔮 Setting up GraphQL...$(NC)"
	@sleep 10
	@$(MAKE) graphql-setup || echo "$(YELLOW)⚠️  GraphQL setup incomplete$(NC)"
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)                   🎉 Setup Complete!                      $(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════$(NC)"
	@$(MAKE) show-env
	@echo ""
	@$(MAKE) urls
	@$(MAKE) status

.PHONY: check-first-migration
check-first-migration:
	@if [ ! -d "$(DIR_MIGRATIONS)" ]; then \
        echo "true"; \
    elif [ -z "$$(find $(DIR_MIGRATIONS) -name '*.cs' 2>/dev/null)" ]; then \
        echo "true"; \
    else \
        echo "false"; \
    fi

.PHONY: dev
dev: check-password check-app-url
	@docker compose up -d
	@echo "$(GREEN)✅ Development mode started$(NC)"
	@$(MAKE) urls

.PHONY: prod
prod: check-password check-app-url
	@docker compose --profile production up -d
	@echo "$(GREEN)✅ Production mode started$(NC)"
	@$(MAKE) urls

# ╔═══════════════════════════════════════════════════════════╗
# ║                   DOCKER OPERATIONS                       ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: build build-no-cache up down restart stop logs status ps

build:
	@echo "$(YELLOW)🏗️  Building containers...$(NC)"
	@docker compose build

build-no-cache:
	@echo "$(YELLOW)🏗️  Building containers (no cache)...$(NC)"
	@docker compose build --no-cache

up:
	@echo "$(YELLOW)🚀 Starting services...$(NC)"
	@docker compose up -d

down:
	@echo "$(YELLOW)⏹️  Stopping services...$(NC)"
	@docker compose down

restart:
	@echo "$(YELLOW)🔄 Restarting services...$(NC)"
	@docker compose restart
	@echo "$(GREEN)✅ Services restarted$(NC)"

stop: down

logs:
	@docker compose logs -f

status:
	@echo "$(CYAN)📊 Container Status$(NC)"
	@docker compose ps

ps: status

# ╔═══════════════════════════════════════════════════════════╗
# ║                   PASSWORD MANAGEMENT                     ║
# ╚═══════════════════════════════════════════════════════════╝

# Password Requirements
PASSWORD_MIN_LENGTH := 8
PASSWORD_MAX_LENGTH := 32

.PHONY: create-password check-password validate-password

create-password:
	@echo "$(YELLOW)🔐 Creating database password...$(NC)"
	@mkdir -p $(DIR_SECRETS)
	@if [ ! -f "$(FILE_PASSWORD)" ]; then \
		echo ""; \
        echo "$(CYAN)╔═══════════════════════════════════════════════════════╗$(NC)"; \
        echo "$(CYAN)║           Password Requirements                       ║$(NC)"; \
        echo "$(CYAN)╠═══════════════════════════════════════════════════════╣$(NC)"; \
        echo "$(CYAN)║  • Length: $(PASSWORD_MIN_LENGTH) - $(PASSWORD_MAX_LENGTH) characters                       ║$(NC)"; \
        echo "$(CYAN)║  • Recommended: mix of letters, numbers, symbols      ║$(NC)"; \
        echo "$(CYAN)╚═══════════════════════════════════════════════════════╝$(NC)"; \
        echo ""; \
        while true; do \
            echo "$(CYAN)Please enter your database password:$(NC)"; \
            read -s password; \
            echo ""; \
            \
            len=$${#password}; \
            \
            if [ $$len -lt $(PASSWORD_MIN_LENGTH) ]; then \
                echo "$(RED)❌ Password too short: $$len characters (minimum: $(PASSWORD_MIN_LENGTH))$(NC)"; \
                echo ""; \
                continue; \
            fi; \
            \
            if [ $$len -gt $(PASSWORD_MAX_LENGTH) ]; then \
                echo "$(RED)❌ Password too long: $$len characters (maximum: $(PASSWORD_MAX_LENGTH))$(NC)"; \
                echo ""; \
                continue; \
            fi; \
            \
            echo "$(CYAN)Please confirm your password:$(NC)"; \
            read -s password_confirm; \
            echo ""; \
            \
            if [ "$$password" = "$$password_confirm" ]; then \
                echo -n "$$password" > $(FILE_PASSWORD); \
                chmod 600 $(FILE_PASSWORD); \
                echo "$(GREEN)✅ Password created successfully$(NC)"; \
                echo "$(GRAY)   Length: $$len characters$(NC)"; \
                echo "$(GRAY)   File: $(FILE_PASSWORD)$(NC)"; \
                break; \
            else \
                echo "$(RED)❌ Passwords do not match$(NC)"; \
                echo ""; \
                read -p "Try again? (Y/n): " retry; \
                if [ "$$retry" = "n" ] || [ "$$retry" = "N" ]; then \
                    echo "$(YELLOW)Cancelled$(NC)"; \
                    exit 1; \
                fi; \
                echo ""; \
            fi; \
        done; \
    else \
        echo "$(YELLOW)⚠️  Password already exists$(NC)"; \
        echo "$(GRAY)   File: $(FILE_PASSWORD)$(NC)"; \
        echo ""; \
        echo "$(CYAN)💡 To change password:$(NC)"; \
        echo "   $(GREEN)make reset-password$(NC)"; \
    fi

# ════════════════════════════════════════════════════════════
# ตรวจสอบความถูกต้องของ password ที่มีอยู่
# ════════════════════════════════════════════════════════════

validate-password:
	@echo "$(CYAN)🔍 Validating password...$(NC)"
	@if [ ! -f "$(FILE_PASSWORD)" ]; then \
        echo "$(RED)❌ Password file not found$(NC)"; \
        exit 1; \
    fi
	@len=$$(cat $(FILE_PASSWORD) | tr -d '\n' | wc -c); \
    if [ $$len -lt $(PASSWORD_MIN_LENGTH) ]; then \
        echo "$(RED)❌ Password too short: $$len characters (minimum: $(PASSWORD_MIN_LENGTH))$(NC)"; \
        exit 1; \
    elif [ $$len -gt $(PASSWORD_MAX_LENGTH) ]; then \
        echo "$(RED)❌ Password too long: $$len characters (maximum: $(PASSWORD_MAX_LENGTH))$(NC)"; \
        exit 1; \
    else \
        echo "$(GREEN)✅ Password valid: $$len characters$(NC)"; \
    fi

check-password:
	@if [ ! -f "$(FILE_PASSWORD)" ]; then \
        echo "$(RED)❌ Password file not found$(NC)"; \
        echo "$(YELLOW)Creating password...$(NC)"; \
        $(MAKE) create-password; \
    else \
        $(MAKE) validate-password; \
    fi

reset-password:
	@echo "$(YELLOW)⚠️  This will delete the existing password$(NC)"
	@read -p "Continue? (y/N): " confirm; \
    if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
        rm -f $(FILE_PASSWORD); \
        echo "$(GREEN)✅ Old password removed$(NC)"; \
        $(MAKE) create-password; \
    else \
        echo "$(YELLOW)Cancelled$(NC)"; \
    fi

password-info:
	@echo "$(CYAN)🔐 Password Information$(NC)"
	@echo "════════════════════════════════════════════════════════════"
	@if [ -f "$(FILE_PASSWORD)" ]; then \
        echo "$(GREEN)✅ Password file exists$(NC)"; \
        echo "   File: $(FILE_PASSWORD)"; \
        echo "   Length: $$(cat $(FILE_PASSWORD) | tr -d '\n' | wc -c) characters"; \
        echo "   Permissions: $$(ls -la $(FILE_PASSWORD) | awk '{print $$1}')"; \
        echo "   Modified: $$(ls -la $(FILE_PASSWORD) | awk '{print $$6, $$7, $$8}')"; \
    else \
        echo "$(RED)❌ Password file not found$(NC)"; \
        echo ""; \
        echo "$(YELLOW)💡 Create password:$(NC)"; \
        echo "   $(GREEN)make create-password$(NC)"; \
    fi
	@echo ""
	@echo "$(YELLOW)Requirements:$(NC)"
	@echo "   Minimum: $(PASSWORD_MIN_LENGTH) characters"
	@echo "   Maximum: $(PASSWORD_MAX_LENGTH) characters"

# ╔═══════════════════════════════════════════════════════════╗
# ║                      INSTALLATION                         ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: install setup-scripts

setup-scripts:
	@echo "$(YELLOW)📜 Setting up scripts...$(NC)"
	@chmod +x $(DIR_SCRIPTS)/setup/*.sh
	@chmod +x $(DIR_SCRIPTS)/database/*.sh
	@chmod +x $(DIR_SCRIPTS)/*.sh
	@echo "$(GREEN)✅ Scripts ready$(NC)"

install: setup-scripts check-password
	@echo "$(YELLOW)💾 Installing database...$(NC)"
	@docker compose $(COMPOSE_PROFILES) up -d $(SERVICE_DB)
	@echo "$(YELLOW)⏳ Waiting for SQL Server...$(NC)"
	@$(MAKE) db-wait
	@echo "$(YELLOW)🔧 Running database setup...$(NC)"
	@docker compose $(COMPOSE_PROFILES) run --rm db-setup
	@echo "$(GREEN)✅ Database installed$(NC)"

# ╔═══════════════════════════════════════════════════════════╗
# ║                     DATABASE OPERATIONS                   ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: db-setup db-wait db-test db-shell db-logs db-debug db-size
.PHONY: db-migrate db-backup db-restore

db-setup: install

db-wait:
	@echo "$(YELLOW)⏳ Waiting for database (timeout: $(TIMEOUT_DB)s)...$(NC)"
	@timeout=$(TIMEOUT_DB); \
	until docker compose exec -T $(SERVICE_DB) /opt/mssql-tools18/bin/sqlcmd \
		-S localhost -U sa -P "$$(cat $(FILE_PASSWORD))" \
		-C -Q "SELECT 1" >/dev/null 2>&1 || [ $$timeout -eq 0 ]; do \
		echo "  ⏳ Waiting... ($$timeout seconds left)"; \
		sleep 5; \
		timeout=$$((timeout - 5)); \
	done; \
	if [ $$timeout -gt 0 ]; then \
		echo "$(GREEN)✅ Database is ready$(NC)"; \
	else \
		echo "$(RED)❌ Database connection timeout$(NC)"; \
		exit 1; \
	fi

db-test:
	@echo "$(CYAN)🧪 Testing database connection$(NC)"
	@docker compose exec -T $(SERVICE_DB) /opt/mssql-tools18/bin/sqlcmd \
		-S localhost -U sa -P "$$(cat $(FILE_PASSWORD))" \
		-C -Q "SELECT @@VERSION" && \
	echo "$(GREEN)✅ Database connection successful$(NC)" || \
	echo "$(RED)❌ Database connection failed$(NC)"

db-shell:
	@echo "$(CYAN)💻 Opening SQL shell...$(NC)"
	@docker compose exec $(SERVICE_DB) /opt/mssql-tools18/bin/sqlcmd \
		-S localhost -U sa -P "$$(cat $(FILE_PASSWORD))" -C

db-logs:
	@docker compose logs -f $(SERVICE_DB)

db-debug:
	@echo "$(CYAN)🐛 Database Debug Info$(NC)"
	@echo ""
	@echo "$(YELLOW)Container Status:$(NC)"
	@docker compose ps $(SERVICE_DB)
	@echo ""
	@echo "$(YELLOW)Recent Logs:$(NC)"
	@docker compose logs --tail=50 $(SERVICE_DB)

db-size:
	@echo "$(CYAN)📊 Database Size$(NC)"
	@docker compose exec -T $(SERVICE_DB) /opt/mssql-tools18/bin/sqlcmd \
		-S localhost -U sa -P "$$(cat $(FILE_PASSWORD))" \
		-C -Q "SELECT \
			DB_NAME(database_id) AS DatabaseName, \
			SUM(size * 8.0 / 1024) AS SizeMB \
			FROM sys.master_files \
			GROUP BY database_id"

db-migrate:
	@if [ -z "$(NAME)" ]; then \
		echo "$(RED)❌ Please provide NAME=MigrationName$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)🔄 Creating migration: $(NAME)$(NC)"
	@docker compose exec $(SERVICE_ASPNETCORE) dotnet ef migrations add $(NAME)
	@echo "$(GREEN)✅ Migration created$(NC)"

db-backup:
	@echo "$(YELLOW)💾 Backing up database...$(NC)"
	@mkdir -p $(DIR_BACKUPS)
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	backup_file="$(DIR_BACKUPS)/$(DATABASE_NAME)_$$timestamp.bak"; \
	docker compose exec -T $(SERVICE_DB) /opt/mssql-tools18/bin/sqlcmd \
		-S localhost -U sa -P "$$(cat $(FILE_PASSWORD))" \
		-C -Q "BACKUP DATABASE $(DATABASE_NAME) TO DISK='/var/opt/mssql/backup/backup.bak'" && \
	docker cp $$(docker compose ps -q $(SERVICE_DB)):/var/opt/mssql/backup/backup.bak $$backup_file && \
	echo "$(GREEN)✅ Backup saved to: $$backup_file$(NC)"

db-restore:
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)❌ Please provide FILE=backup.bak$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)📥 Restoring database from: $(FILE)$(NC)"
	@docker cp $(FILE) $$(docker compose ps -q $(SERVICE_DB)):/var/opt/mssql/backup/restore.bak
	@docker compose exec -T $(SERVICE_DB) /opt/mssql-tools18/bin/sqlcmd \
		-S localhost -U sa -P "$$(cat $(FILE_PASSWORD))" \
		-C -Q "RESTORE DATABASE $(DATABASE_NAME) FROM DISK='/var/opt/mssql/backup/restore.bak' WITH REPLACE"
	@echo "$(GREEN)✅ Database restored$(NC)"

# ╔═══════════════════════════════════════════════════════════╗
# ║                   FRONTEND OPERATIONS                     ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: frontend-build frontend-logs frontend-shell frontend-restart
.PHONY: npm-install npm-update type-check lint test

frontend-build:
	@echo "$(YELLOW)🎨 Building frontend...$(NC)"
	@docker compose build $(SERVICE_FRONTEND)
	@echo "$(GREEN)✅ Frontend built$(NC)"

frontend-logs:
	@docker compose logs -f $(SERVICE_FRONTEND)

frontend-shell:
	@echo "$(CYAN)💻 Opening frontend shell...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) /bin/sh

frontend-restart:
	@echo "$(YELLOW)🔄 Restarting frontend...$(NC)"
	@docker compose restart $(SERVICE_FRONTEND)
	@echo "$(GREEN)✅ Frontend restarted$(NC)"

npm-install:
	@echo "$(YELLOW)📦 Installing npm packages...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm install
	@echo "$(GREEN)✅ Packages installed$(NC)"

npm-update:
	@echo "$(YELLOW)📦 Updating npm packages...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm update
	@echo "$(GREEN)✅ Packages updated$(NC)"

type-check:
	@echo "$(YELLOW)🔍 Running TypeScript check...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run type-check

lint:
	@echo "$(YELLOW)🔍 Running linter...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run lint

test:
	@echo "$(YELLOW)🧪 Running tests...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm test

# ╔═══════════════════════════════════════════════════════════╗
# ║                   GRAPHQL OPERATIONS                      ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: graphql-setup graphql-wait graphql-test graphql-check graphql-reset
.PHONY: graphql-generate graphql-download graphql-watch graphql-validate
.PHONY: graphql-info graphql-status graphql-clean graphql-health

graphql-setup:
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)              Setting up GraphQL                           $(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@$(MAKE) graphql-wait
	@$(MAKE) graphql-download
	@$(MAKE) graphql-generate
	@$(MAKE) graphql-test
	@echo "$(GREEN)✅ GraphQL setup complete$(NC)"

graphql-wait:
	@echo "$(YELLOW)⏳ Waiting for GraphQL (timeout: $(TIMEOUT_GRAPHQL)s)...$(NC)"
	@timeout=$(TIMEOUT_GRAPHQL); \
	until curl -sf http://localhost:5000/graphql >/dev/null 2>&1 || [ $$timeout -eq 0 ]; do \
		echo "  ⏳ Waiting... ($$timeout seconds left)"; \
		sleep 5; \
		timeout=$$((timeout - 5)); \
	done; \
	if [ $$timeout -gt 0 ]; then \
		echo "$(GREEN)✅ GraphQL endpoint is ready$(NC)"; \
	else \
		echo "$(RED)❌ GraphQL endpoint timeout$(NC)"; \
		exit 1; \
	fi

graphql-test:
	@echo "$(CYAN)🧪 Testing GraphQL endpoint$(NC)"
	@curl -sf http://localhost:5000/graphql \
		-H "Content-Type: application/json" \
		-d '{"query":"{ __schema { queryType { name } } }"}' \
		>/dev/null 2>&1 && \
	echo "$(GREEN)✅ GraphQL endpoint is working$(NC)" || \
	echo "$(RED)❌ GraphQL endpoint is not responding$(NC)"

graphql-check:
	@echo "$(CYAN)🔍 Checking GraphQL schema$(NC)"
	@if [ -f "$(FILE_SCHEMA)" ]; then \
		echo "$(GREEN)✅ Schema file exists$(NC)"; \
		ls -lh $(FILE_SCHEMA); \
	else \
		echo "$(RED)❌ Schema file not found$(NC)"; \
	fi

graphql-reset:
	@echo "$(YELLOW)🔄 Resetting GraphQL files...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) rm -rf apollo/generated/* apollo/schema.graphql
	@echo "$(GREEN)✅ GraphQL files reset$(NC)"
	@$(MAKE) graphql-setup

graphql-generate:
	@echo "$(YELLOW)🔮 Generating GraphQL client...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run graphql:codegen
	@echo "$(GREEN)✅ GraphQL client generated$(NC)"

graphql-download:
	@echo "$(YELLOW)📥 Downloading GraphQL schema...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run graphql:download
	@echo "$(GREEN)✅ Schema downloaded$(NC)"

graphql-watch:
	@echo "$(YELLOW)👀 Starting GraphQL codegen watch mode...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run graphql:watch

graphql-validate:
	@echo "$(YELLOW)✅ Validating GraphQL schema...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run graphql:validate

graphql-info:
	@echo "$(CYAN)ℹ️  GraphQL Configuration$(NC)"
	@echo ""
	@echo "$(YELLOW)Endpoint:$(NC) http://localhost:5000/graphql"
	@echo "$(YELLOW)Schema:$(NC) $(FILE_SCHEMA)"
	@echo "$(YELLOW)Generated:$(NC) $(DIR_APOLLO)/generated"

graphql-status:
	@echo "$(CYAN)📊 GraphQL Status$(NC)"
	@curl -sf http://localhost:5000/graphql >/dev/null 2>&1 && \
		echo "$(GREEN)✅ Endpoint: OK$(NC)" || \
		echo "$(RED)❌ Endpoint: DOWN$(NC)"
	@[ -f "$(FILE_SCHEMA)" ] && \
		echo "$(GREEN)✅ Schema: OK$(NC)" || \
		echo "$(RED)❌ Schema: Missing$(NC)"

graphql-clean:
	@echo "$(YELLOW)🧹 Cleaning generated files...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) rm -rf apollo/generated/*
	@echo "$(GREEN)✅ Clean complete$(NC)"

graphql-health:
	@echo "$(CYAN)🏥 Testing GraphQL health$(NC)"
	@curl -sf http://localhost:5000/health || echo "$(RED)❌ Health check failed$(NC)"

# ╔═══════════════════════════════════════════════════════════╗
# ║                     VOLUME MANAGEMENT                     ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: volumes-init volumes-check volumes-fix volumes-list volumes-clean

volumes-init:
	@echo "$(YELLOW)📁 Initializing volumes...$(NC)"
	@mkdir -p $(DIR_DATABASE)/data $(DIR_DATABASE)/log $(DIR_DATABASE)/backup
	@chmod 755 $(DIR_DATABASE)/data $(DIR_DATABASE)/log $(DIR_DATABASE)/backup
	@echo "$(GREEN)✅ Volumes initialized$(NC)"

volumes-check:
	@echo "$(CYAN)🔍 Checking volume permissions$(NC)"
	@ls -la $(DIR_DATABASE)

volumes-fix:
	@echo "$(YELLOW)🔧 Fixing volume permissions...$(NC)"
	@chmod -R 755 $(DIR_DATABASE)
	@echo "$(GREEN)✅ Permissions fixed$(NC)"

volumes-list:
	@echo "$(CYAN)📊 Project Volumes$(NC)"
	@docker volume ls | grep $(PROJECT_NAME) || echo "$(YELLOW)No volumes found$(NC)"

volumes-clean:
	@echo "$(RED)⚠️  This will remove all volumes!$(NC)"
	@read -p "Continue? (yes/NO): " confirm; \
	[ "$$confirm" = "yes" ] || exit 0
	@docker compose down -v
	@echo "$(GREEN)✅ Volumes removed$(NC)"

# ╔═══════════════════════════════════════════════════════════╗
# ║                   HEALTH & MONITORING                     ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: health health-full wait-health urls quick

health:
	@echo "$(CYAN)🏥 Quick Health Check$(NC)"
	@echo ""
	@curl -sf http://localhost:5000/health >/dev/null 2>&1 && \
		echo "$(GREEN)✅ Backend: OK$(NC)" || \
		echo "$(RED)❌ Backend: DOWN$(NC)"
	@curl -sf http://localhost:5173 >/dev/null 2>&1 && \
		echo "$(GREEN)✅ Frontend: OK$(NC)" || \
		echo "$(RED)❌ Frontend: DOWN$(NC)"
	@docker compose exec -T $(SERVICE_DB) /opt/mssql-tools18/bin/sqlcmd \
		-S localhost -U sa -P "$$(cat $(FILE_PASSWORD))" \
		-C -Q "SELECT 1" >/dev/null 2>&1 && \
		echo "$(GREEN)✅ Database: OK$(NC)" || \
		echo "$(RED)❌ Database: DOWN$(NC)"

health-full:
	@echo "$(CYAN)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)              Detailed Health Report                       $(NC)"
	@echo "$(CYAN)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@$(MAKE) status
	@echo ""
	@$(MAKE) health
	@echo ""
	@$(MAKE) graphql-status

wait-health:
	@echo "$(YELLOW)⏳ Waiting for all services (timeout: $(TIMEOUT_HEALTH)s)...$(NC)"
	@timeout=$(TIMEOUT_HEALTH); \
	until curl -sf http://localhost:5000/health >/dev/null 2>&1 && \
		  curl -sf http://localhost:5173 >/dev/null 2>&1 || \
		  [ $$timeout -eq 0 ]; do \
		echo "  ⏳ Waiting... ($$timeout seconds left)"; \
		sleep 10; \
		timeout=$$((timeout - 10)); \
	done; \
	if [ $$timeout -gt 0 ]; then \
		echo "$(GREEN)✅ All services are healthy$(NC)"; \
	else \
		echo "$(RED)❌ Health check timeout$(NC)"; \
		exit 1; \
	fi

urls:
	@echo "$(CYAN)🔗 Service URLs$(NC)"
	@echo ""
	@echo "$(YELLOW)Frontend:$(NC)     http://localhost:5173"
	@echo "$(YELLOW)Backend:$(NC)      http://localhost:5000"
	@echo "$(YELLOW)GraphQL:$(NC)      http://localhost:5000/graphql"
	@echo "$(YELLOW)Swagger:$(NC)      http://localhost:5000/swagger"
	@echo "$(YELLOW)Nginx:$(NC)        http://localhost:8080"

quick:
	@echo "$(CYAN)⚡ Quick System Check$(NC)"
	@echo ""
	@$(MAKE) status
	@echo ""
	@$(MAKE) health

# ╔═══════════════════════════════════════════════════════════╗
# ║                      MAINTENANCE                          ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: clean rebuild reset fix-line-endings

clean:
	@echo "$(YELLOW)🧹 Cleaning containers...$(NC)"
	@docker compose down
	@echo "$(GREEN)✅ Containers removed$(NC)"

rebuild:
	@echo "$(YELLOW)🔄 Rebuilding everything...$(NC)"
	@docker compose down
	@docker compose build --no-cache
	@docker compose up -d
	@echo "$(GREEN)✅ Rebuild complete$(NC)"

reset:
	@echo "$(RED)⚠️  FULL RESET - This will remove all data!$(NC)"
	@read -p "Type 'yes' to continue: " confirm; \
	[ "$$confirm" = "yes" ] || exit 0
	@echo "$(YELLOW)1. Stopping services...$(NC)"
	@docker compose down -v
	@echo "$(YELLOW)2. Removing volumes...$(NC)"
	@rm -rf $(DIR_DATABASE)/data/* $(DIR_DATABASE)/log/* $(DIR_DATABASE)/backup/*
	@echo "$(YELLOW)3. Cleaning build cache...$(NC)"
	@docker builder prune -f
	@echo "$(GREEN)✅ Reset complete$(NC)"
	@echo "$(YELLOW)Run 'make first-run' to start fresh$(NC)"

fix-line-endings:
	@echo "$(YELLOW)🔧 Fixing line endings...$(NC)"
	@if command -v dos2unix >/dev/null 2>&1; then \
		find $(DIR_SCRIPTS) -type f -name "*.sh" -exec dos2unix {} \; ; \
		echo "$(GREEN)✅ Line endings fixed$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  dos2unix not found, using sed...$(NC)"; \
		find $(DIR_SCRIPTS) -type f -name "*.sh" -exec sed -i 's/\r$$//' {} \; ; \
		echo "$(GREEN)✅ Line endings fixed$(NC)"; \
	fi
	@$(MAKE) setup-scripts

# ╔═══════════════════════════════════════════════════════════╗
# ║                   WINDOWS SUPPORT                         ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: windows-quick-start windows-fix-line-endings

windows-quick-start:
	@echo "$(CYAN)🪟 Windows Quick Start$(NC)"
	@echo ""
	@echo "$(YELLOW)1. Checking prerequisites...$(NC)"
	@$(MAKE) check-tools
	@echo ""
	@echo "$(YELLOW)2. Fixing line endings...$(NC)"
	@$(MAKE) windows-fix-line-endings
	@echo ""
	@echo "$(YELLOW)3. Starting setup...$(NC)"
	@$(MAKE) first-run

windows-fix-line-endings:
	@echo "$(YELLOW)🔧 Fixing line endings (Windows)...$(NC)"
	@powershell -Command "Get-ChildItem -Path $(DIR_SCRIPTS) -Filter *.sh -Recurse | ForEach-Object { \
		$$content = Get-Content $$_.FullName -Raw; \
		$$content = $$content -replace '`r`n', '`n'; \
		Set-Content -Path $$_.FullName -Value $$content -NoNewline; \
	}"
	@echo "$(GREEN)✅ Line endings fixed$(NC)"

# ╔═══════════════════════════════════════════════════════════╗
# ║                   SSH MANAGEMENT                          ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: ssh-start ssh-stop ssh-restart ssh-logs ssh-status ssh-help
.PHONY: ssh-keygen ssh-hardening

ssh-start:
	@echo "$(YELLOW)🔑 Starting SSH server...$(NC)"
	@docker compose --profile ssh up -d openssh-server
	@echo "$(GREEN)✅ SSH server started$(NC)"
	@echo ""
	@echo "$(CYAN)Connection Info:$(NC)"
	@echo "  Host: localhost"
	@echo "  Port: 2222"
	@echo "  User: developer"
	@echo ""
	@echo "$(YELLOW)Connect with:$(NC)"
	@echo "  ssh -p 2222 developer@localhost"

ssh-stop:
	@echo "$(YELLOW)🛑 Stopping SSH server...$(NC)"
	@docker compose --profile ssh stop openssh-server
	@echo "$(GREEN)✅ SSH server stopped$(NC)"

ssh-restart:
	@$(MAKE) ssh-stop
	@$(MAKE) ssh-start

ssh-logs:
	@docker compose logs -f openssh-server

ssh-status:
	@echo "$(CYAN)📊 SSH Status$(NC)"
	@docker ps -a --filter "name=openssh" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

ssh-help:
	@echo "$(CYAN)SSH Commands:$(NC)"
	@echo "  make ssh-start     - Start SSH server"
	@echo "  make ssh-stop      - Stop SSH server"
	@echo "  make ssh-restart   - Restart SSH server"
	@echo "  make ssh-logs      - View SSH logs"
	@echo "  make ssh-status    - Show SSH status"

ssh-keygen:
	@echo "$(YELLOW)🔑 Generating SSH keys...$(NC)"
	@mkdir -p ~/.ssh
	@ssh-keygen -t ed25519 -C "developer@$(PROJECT_NAME)" -f ~/.ssh/$(PROJECT_NAME)
	@echo "$(GREEN)✅ SSH keys generated$(NC)"
	@echo ""
	@echo "$(CYAN)Add this to your authorized_keys:$(NC)"
	@cat ~/.ssh/$(PROJECT_NAME).pub

ssh-hardening:
	@echo "$(YELLOW)🔒 Setting up SSH hardening...$(NC)"
	@mkdir -p scripts/setup
	@cp templates/ssh-hardening.sh scripts/setup/
	@chmod +x scripts/setup/ssh-hardening.sh
	@echo "$(GREEN)✅ SSH hardening script created$(NC)"

# ╔═══════════════════════════════════════════════════════════╗
# ║                   DEBUGGING & UTILITIES                   ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: debug debug-env check-tools open open-swagger open-graphql

debug:
	@echo "$(CYAN)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)                   Debug Information                       $(NC)"
	@echo "$(CYAN)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)System:$(NC)"
	@echo "  OS: $(UNAME_S)"
	@echo "  Project: $(PROJECT_NAME)"
	@echo ""
	@echo "$(YELLOW)Timeouts:$(NC)"
	@echo "  DB: $(TIMEOUT_DB)s"
	@echo "  GraphQL: $(TIMEOUT_GRAPHQL)s"
	@echo "  Health: $(TIMEOUT_HEALTH)s"
	@echo ""
	@$(MAKE) status
	@echo ""
	@$(MAKE) health

debug-env:
	@echo "$(CYAN)Environment Variables$(NC)"
	@echo ""
	@echo "$(YELLOW)Frontend:$(NC)"
	@docker compose exec -T $(SERVICE_FRONTEND) env | grep -E '^(VITE_|NODE_)' | sort
	@echo ""
	@echo "$(YELLOW)Backend:$(NC)"
	@docker compose exec -T $(SERVICE_ASPNETCORE) env | grep -E '^(ASPNETCORE_|DATABASE_)' | sort

check-tools:
	@echo "$(YELLOW)Checking Host Tools...$(NC)"
	@for tool in bash docker make curl; do \
		if command -v $$tool >/dev/null 2>&1; then \
			echo "  ✅ $$tool"; \
		else \
			echo "  ❌ $$tool - MISSING"; \
		fi; \
	done
	@for tool in dos2unix jq; do \
		if command -v $$tool >/dev/null 2>&1; then \
			echo "  ✅ $$tool (optional)"; \
		else \
			echo "  ⚠️  $$tool (optional)"; \
		fi; \
	done

open:
	@$(OPEN_CMD) http://localhost:5173

open-swagger:
	@$(OPEN_CMD) http://localhost:5000/swagger

open-graphql:
	@$(OPEN_CMD) http://localhost:5000/graphql

# ╔═══════════════════════════════════════════════════════════╗
# ║                  EMERGENCY & QUICK FIXES                  ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: emergency-reset quick-fix

emergency-reset:
	@echo "$(RED)⚠️  EMERGENCY RESET$(NC)"
	@read -p "This will restart everything. Continue? (yes/NO): " confirm; \
	[ "$$confirm" = "yes" ] || exit 0
	@echo "$(YELLOW)1. Stopping services...$(NC)"
	@docker compose down
	@echo "$(YELLOW)2. Cleaning caches...$(NC)"
	@docker compose exec -T $(SERVICE_FRONTEND) rm -rf node_modules/.cache apollo/generated/* 2>/dev/null || true
	@echo "$(YELLOW)3. Starting services...$(NC)"
	@docker compose up -d
	@echo "$(YELLOW)4. Waiting for health...$(NC)"
	@sleep 30
	@$(MAKE) wait-health
	@echo "$(YELLOW)5. Setting up GraphQL...$(NC)"
	@$(MAKE) graphql-setup
	@echo "$(GREEN)✅ Emergency reset complete$(NC)"
	@$(MAKE) quick

quick-fix: fix-line-endings frontend-build frontend-restart
	@echo "$(GREEN)✅ Quick fix applied$(NC)"
	@$(MAKE) frontend-logs

# ╔═══════════════════════════════════════════════════════════╗
# ║                   CONFIGURATION TOOLS                     ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: check-app-url assign-app-url show-env test-app-url

check-app-url:
	@echo "$(CYAN)🔍 Checking APP_URL Configuration$(NC)"
	@echo ""
	@if [ -f .env ]; then \
		APP_URL=$$(grep -E "^APP_URL=" .env | cut -d'=' -f2); \
		FRONTEND_URL=$$(grep -E "^FRONTEND_URL=" .env | cut -d'=' -f2); \
		VITE_APP_URL=$$(grep -E "^VITE_APP_URL=" .env | cut -d'=' -f2); \
		echo "  APP_URL:       $$APP_URL"; \
		echo "  FRONTEND_URL:  $$FRONTEND_URL"; \
		echo "  VITE_APP_URL:  $$VITE_APP_URL"; \
		if [ -z "$$APP_URL" ]; then \
			echo "$(RED)  ⚠️  APP_URL not set!$(NC)"; \
		else \
			echo "$(GREEN)  ✅ APP_URL configured$(NC)"; \
		fi; \
	else \
		echo "$(RED)❌ .env file not found$(NC)"; \
	fi

assign-app-url:
	@echo "$(CYAN)🔧 Setting APP_URL$(NC)"
	@read -p "Enter APP_URL (e.g., http://localhost:8080): " url; \
	if [ -n "$$url" ]; then \
		if [ -f .env ]; then \
			$(SED_INPLACE) "s|^APP_URL=.*|APP_URL=$$url|" .env; \
			$(SED_INPLACE) "s|^FRONTEND_URL=.*|FRONTEND_URL=$$url|" .env; \
			$(SED_INPLACE) "s|^VITE_APP_URL=.*|VITE_APP_URL=$$url|" .env; \
			echo "$(GREEN)✅ APP_URL updated to: $$url$(NC)"; \
		else \
			echo "$(RED)❌ .env file not found$(NC)"; \
		fi; \
	fi

show-env:
	@echo "$(CYAN)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)            Environment Configuration                      $(NC)"
	@echo "$(CYAN)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)📍 Main URLs:$(NC)"
	@if [ -f .env ]; then \
		grep -E "^(APP_URL|FRONTEND_URL|VITE_APP_URL)=" .env | while read line; do \
			echo "  $$line"; \
		done; \
	fi
	@echo ""
	@echo "$(YELLOW)🔗 Internal URLs (Docker):$(NC)"
	@if [ -f .env ]; then \
		grep -E "^VITE_(API_URL|GRAPHQL_ENDPOINT|GRPC_ENDPOINT)=" .env | while read line; do \
			echo "  $$line"; \
		done; \
	fi
	@echo ""
	@echo "$(YELLOW)🌐 Public URLs (Browser):$(NC)"
	@if [ -f .env ]; then \
		grep -E "^VITE_PUBLIC_" .env | while read line; do \
			echo "  $$line"; \
		done; \
	fi

test-app-url:
	@echo "$(CYAN)🧪 Testing APP_URL$(NC)"
	@if [ -f .env ]; then \
		APP_URL=$$(grep -E "^APP_URL=" .env | cut -d'=' -f2); \
		echo "  Testing: $$APP_URL"; \
		if curl -sf "$$APP_URL/health" >/dev/null 2>&1; then \
			echo "$(GREEN)  ✅ URL accessible$(NC)"; \
		else \
			echo "$(YELLOW)  ⚠️  URL not accessible (service may not be running)$(NC)"; \
		fi; \
	fi

# ╔═══════════════════════════════════════════════════════════╗
# ║              BACKWARD COMPATIBILITY ALIASES               ║
# ╚═══════════════════════════════════════════════════════════╝

# Aliases เพื่อรองรับคำสั่งเก่า
.PHONY: wait-for-db wait-for-graphql test-db test-graphql
.PHONY: generate-graphql-safe check-graphql fix-all-graphql migration
.PHONY: graphql-fix restart-docker

wait-for-db: db-wait
wait-for-graphql: graphql-wait
test-db: db-test
test-graphql: graphql-test
generate-graphql-safe: graphql-generate
check-graphql: graphql-check
fix-all-graphql: graphql-setup
migration: db-migrate
graphql-fix: graphql-setup
restart-docker: restart

# Aliases ใหม่สำหรับ migration
.PHONY: ef-first ef-add ef-apply ef-fix ef-status
ef-first: migration-first
ef-add: migration-add
ef-apply: migration-apply
ef-fix: migration-fix
ef-status: migration-status