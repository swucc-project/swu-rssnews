.DEFAULT_GOAL := help

# ╔═══════════════════════════════════════════════════════════╗
# ║                      CONFIGURATION                        ║
# ╚═══════════════════════════════════════════════════════════╝

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
BLUE   := \033[0;34m
CYAN   := \033[0;36m
NC     := \033[0m

# Project Settings
PROJECT_NAME := swu-rssnews
COMPOSE_PROFILES := --profile setup --profile migration

# Service Names (ตรงกับ docker-compose.yml)
SERVICE_ASPNETCORE := aspdotnetweb
SERVICE_DB := mssql
SERVICE_FRONTEND := frontend
SERVICE_NGINX := web-server

# Endpoints (ใช้ service names จาก Docker network)
GRAPHQL_ENDPOINT := http://$(SERVICE_ASPNETCORE):5000/graphql
HEALTH_ENDPOINT := http://$(SERVICE_ASPNETCORE):5000/health

# Timeout (seconds)
TIMEOUT_DB := 60
TIMEOUT_GRAPHQL := 90
TIMEOUT_HEALTH := 180

# Directories
DIR_DATABASE := ./database
DIR_FRONTEND := ./vite-ui
DIR_APOLLO := $(DIR_FRONTEND)/apollo
DIR_SCRIPTS := $(DIR_FRONTEND)/scripts
DIR_SECRETS := ./secrets
DIR_MIGRATIONS := ./aspnetcore/Migrations

# Files
FILE_PASSWORD := $(DIR_SECRETS)/db_password.txt
FILE_ENTRYPOINT := $(DIR_SCRIPTS)/docker-entrypoint.sh
FILE_SCHEMA := $(DIR_APOLLO)/schema.graphql

APOLLO_BIN = npx -p @apollo/client apollo

GRAPHQL_SCRIPTS := vite-ui/scripts/graphql/graphql-utils.sh
GRAPHQL_LOGIC := bash -c '. $(GRAPHQL_SCRIPTS); <your-func>'
GRAPHQL_SCHEMA_FILE := $(DIR_APOLLO)/schema.graphql
GRAPHQL_GENERATED_DIR := $(DIR_APOLLO)/generated
GRAPHQL_IS_PLACEHOLDER := $(shell grep -q "_placeholder" $(GRAPHQL_SCHEMA_FILE) && echo true || echo false)
GRAPHQL_IS_REAL := $(if $(GRAPHQL_IS_PLACEHOLDER),false,true)

# OS Detection
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    SED_INPLACE := sed -i ''
else
    SED_INPLACE := sed -i
endif

# ╔═══════════════════════════════════════════════════════════╗
# ║                         HELP                              ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: help
help:
	@echo ""
	@echo "$(BLUE)╔═══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║         SWU RSS News Docker Management Commands           ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(CYAN)📦 QUICK START$(NC)"
	@echo "  $(GREEN)make first-run$(NC)           - ติดตั้งและรันโปรเจ็กต์ครั้งแรก"
	@echo "  $(GREEN)make dev$(NC)                 - รัน development mode"
	@echo "  $(GREEN)make status$(NC)              - ดูสถานะ services"
	@echo ""
	@echo "$(CYAN)🔧 INSTALLATION & SETUP$(NC)"
	@echo "  $(GREEN)make create-password$(NC)     - สร้างรหัสผ่าน database"
	@echo "  $(GREEN)make install$(NC)             - ติดตั้ง database & migrations"
	@echo "  $(GREEN)make build$(NC)               - Build Docker images"
	@echo ""
	@echo "$(CYAN)🚀 RUNNING$(NC)"
	@echo "  $(GREEN)make dev$(NC)                 - รัน development mode"
	@echo "  $(GREEN)make prod$(NC)                - รัน production mode"
	@echo "  $(GREEN)make stop$(NC)                - หยุด services"
	@echo "  $(GREEN)make restart$(NC)             - Restart services"
	@echo ""
	@echo "$(CYAN)🎨 FRONTEND$(NC)"
	@echo "  $(GREEN)make frontend-dev$(NC)        - รัน Vite dev server"
	@echo "  $(GREEN)make frontend-logs$(NC)       - ดู frontend logs"
	@echo "  $(GREEN)make frontend-shell$(NC)      - เข้า frontend shell"
	@echo ""
	@echo "$(CYAN)🔮 GRAPHQL$(NC)"
	@echo "  $(GREEN)make graphql-generate$(NC)    - สร้าง GraphQL client (แนะนำ)"
	@echo "  $(GREEN)make graphql-test$(NC)        - ทดสอบ GraphQL endpoint"
	@echo "  $(GREEN)make graphql-check$(NC)       - ตรวจสอบ schema files"
	@echo "  $(GREEN)make graphql-fix$(NC)         - แก้ไขปัญหา GraphQL"
	@echo "  $(GREEN)make graphql-watch$(NC)       - Watch mode สำหรับ codegen"
	@echo "  $(GREEN)make graphql-validate$(NC)    - Validate setup"
	@echo "  $(GREEN)make graphql-reset$(NC)       - Reset everything (⚠️  destructive)"
	@echo "  $(GREEN)make graphql-info$(NC)        - Show configuration info"
	@echo ""
	@echo "$(CYAN)🐛 GRAPHQL DEBUG$(NC)"
	@echo "  $(GREEN)make graphql-status$(NC)      - สรุปสถานะแบบเร็ว"
	@echo "  $(GREEN)make graphql-clean$(NC)       - ล้าง generated files เฉยๆ"
	@echo "  $(GREEN)make graphql-health$(NC)      - ทดสอบ health endpoint"
	@echo "$(CYAN)🗄️ DATABASE$(NC)"
	@echo "  $(GREEN)make db-test$(NC)             - ทดสอบการเชื่อมต่อ"
	@echo "  $(GREEN)make db-shell$(NC)            - เข้า SQL Server shell"
	@echo "  $(GREEN)make db-migration NAME=xxx$(NC) - สร้าง migration ใหม่"
	@echo ""
	@echo "$(CYAN)🧹 MAINTENANCE$(NC)"
	@echo "  $(GREEN)make clean$(NC)               - ลบ containers"
	@echo "  $(GREEN)make rebuild$(NC)             - Rebuild containers"
	@echo "  $(GREEN)make reset$(NC)               - ลบข้อมูลทั้งหมด (ระวัง!)"
	@echo ""

# ╔═══════════════════════════════════════════════════════════╗
# ║                    HELPER FUNCTIONS                       ║
# ╚═══════════════════════════════════════════════════════════╝

# Cross-platform sed with backup
define sed_replace
	@if [ "$(UNAME_S)" = "Darwin" ]; then \
        sed -i '' '$(1)' $(2); \
    else \
        sed -i '$(1)' $(2); \
    fi
endef

# Wait for service with timeout
define wait_for_service
	@echo "$(YELLOW)⏳ Waiting for $(1)...$(NC)"; \
    elapsed=0; \
    while [ $$elapsed -lt $(2) ]; do \
        if $(3); then \
            echo "$(GREEN)✅ $(1) is ready ($$elapsed/$(2)s)$(NC)"; \
            exit 0; \
        fi; \
        printf "\r  Waiting... $$elapsed/$(2)s"; \
        sleep 5; \
        elapsed=$$((elapsed + 5)); \
    done; \
    echo "$(RED)❌ Timeout waiting for $(1)$(NC)"; \
    exit 1
endef

# ╔═══════════════════════════════════════════════════════════╗
# ║                    INSTALLATION                           ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: create-password check-password
create-password:
	@echo "$(BLUE)Creating Database Password$(NC)"
	@mkdir -p $(DIR_SECRETS) && chmod 700 $(DIR_SECRETS)
	@if [ -f "$(FILE_PASSWORD)" ]; then \
        echo "$(YELLOW)⚠️  Password exists!$(NC)"; \
        read -p "Override? (y/N): " confirm; \
        [ "$$confirm" = "y" ] || exit 1; \
    fi
	@echo "$(YELLOW)Requirements: 8+ chars, 3 of: upper/lower/digit/symbol$(NC)"
	@while true; do \
        read -s -p "Password: " pass1; echo ""; \
        [ -n "$$pass1" ] || { echo "$(RED)Empty!$(NC)"; continue; }; \
        [ $$(echo "$$pass1" | wc -c) -ge 9 ] || { echo "$(RED)Too short!$(NC)"; continue; }; \
        read -s -p "Confirm: " pass2; echo ""; \
        [ "$$pass1" = "$$pass2" ] || { echo "$(RED)Mismatch!$(NC)"; continue; }; \
        echo -n "$$pass1" > $(FILE_PASSWORD) && chmod 600 $(FILE_PASSWORD); \
        break; \
    done
	@echo "$(GREEN)✅ Password saved$(NC)"

check-password:
	@if [ ! -f "$(FILE_PASSWORD)" ]; then \
        echo "$(RED)❌ Password file not found$(NC)"; \
        exit 1; \
    fi

.PHONY: setup-scripts
setup-scripts:
	@echo "$(BLUE)Setting Up Scripts$(NC)"
	@chmod +x $(DIR_DATABASE)/*.sh 2>/dev/null || true
	@chmod +x $(DIR_SCRIPTS)/*.sh 2>/dev/null || true
	@chmod +x ./aspnetcore/add-migration.sh || true
	@echo "$(GREEN)✅ Scripts configured$(NC)"

.PHONY: fix-line-endings
fix-line-endings:
	@echo "$(BLUE)Fixing Line Endings$(NC)"
	@for file in $(DIR_SCRIPTS)/*.sh $(DIR_DATABASE)/*.sh ./aspnetcore/add-migration.sh ./vite-ui/scripts/*.sh ./vite-ui/scripts/docker-entrypoint.sh; do \
        if [ -f "$$file" ]; then \
            if command -v dos2unix >/dev/null 2>&1; then \
                dos2unix "$$file" 2>/dev/null; \
            else \
                $(SED_INPLACE) 's/\r$$//' "$$file"; \
            fi; \
            echo "  ✅ $$(basename $$file)"; \
        fi; \
    done

.PHONY: first-run
first-run:
	@echo "$(BLUE)╔═══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║          First Time Setup                                  ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════════════╝$(NC)"
	@[ -f "$(FILE_PASSWORD)" ] || $(MAKE) create-password
	@echo "$(YELLOW)🧹 Cleaning...$(NC)"
	@docker compose $(COMPOSE_PROFILES) down -v 2>/dev/null || true
	@echo "$(YELLOW)📦 Initializing volumes...$(NC)"
	@$(DIR_DATABASE)/begin-volumes.sh
	@echo "$(YELLOW)🏗️ Building...$(NC)"
	@$(MAKE) build
	@echo "$(YELLOW)💾 Installing database...$(NC)"
	@$(MAKE) install
	@echo "$(YELLOW)🚀 Starting services...$(NC)"
	@docker compose up -d
	@$(MAKE) wait-for-health
	@echo "$(YELLOW)🔧 Installing GraphQL tools...$(NC)"
	@$(MAKE) install-graphql-utilities
	@echo "$(YELLOW)🔮 Setting up GraphQL...$(NC)"
	@sleep 10
	@$(MAKE) graphql-setup || echo "$(YELLOW)⚠️  GraphQL setup incomplete$(NC)"
	@echo "$(GREEN)╔═══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║          🎉 Setup Complete!                               ║$(NC)"
	@echo "$(GREEN)╚═══════════════════════════════════════════════════════════╝$(NC)"
	@$(MAKE) show-urls
	@$(MAKE) status

.PHONY: install
install: check-password setup-scripts
	@echo "$(BLUE)Installing Database$(NC)"
	@docker compose up -d $(SERVICE_DB)
	@$(MAKE) wait-for-db
	@docker compose --profile setup run --rm queue-db-migration
	@docker compose --profile migration run --rm migration-db
	@echo "$(GREEN)✅ Database installed$(NC)"

.PHONY: build
build:
	@echo "$(CYAN)📦 Building Images...$(NC)"
	@docker compose build

# ╔═══════════════════════════════════════════════════════════╗
# ║                         RUNNING                           ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: dev prod stop restart
dev: check-password
	@docker compose up -d
	@echo "$(GREEN)✅ Development started$(NC)"
	@$(MAKE) show-urls

prod: check-password
	@docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
	@echo "$(GREEN)✅ Production started$(NC)"

stop:
	@docker compose $(COMPOSE_PROFILES) down
	@echo "$(GREEN)✅ Stopped$(NC)"

restart: stop dev

# ╔═══════════════════════════════════════════════════════════╗
# ║                        FRONTEND                           ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: frontend-dev frontend-logs frontend-shell frontend-restart
frontend-dev:
	@docker compose exec $(SERVICE_FRONTEND) npm run dev

frontend-logs:
	@docker compose logs -f $(SERVICE_FRONTEND)

frontend-shell:
	@docker compose exec $(SERVICE_FRONTEND) bash

frontend-restart:
	@docker compose restart $(SERVICE_FRONTEND)
	@echo "$(GREEN)✅ Frontend restarted$(NC)"

# ╔═══════════════════════════════════════════════════════════╗
# ║                        GRAPHQL                            ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: graphql
.PHONY: graphql-setup graphql-download graphql-generate
.PHONY: graphql-assure graphql-wait graphql-test graphql-check
.PHONY: graphql-fix-safe graphql-watch graphql-validate graphql-reset
.PHONY: graphql-status
.PHONY: graphql-health

graphql: graphql-assure graphql-download graphql-generate

graphql-fallback: graphql-assure

# Main GraphQL setup (ใช้ใน first-run)
graphql-setup: graphql-wait graphql-assure graphql-download graphql-generate
	@echo "$(GREEN)✅ GraphQL setup complete$(NC)"

# สร้าง placeholder files
graphql-assure:
	@echo "$(BLUE)Creating Placeholder Files$(NC)"
	@docker compose exec -T $(SERVICE_FRONTEND) npm run assure-files || true
	@echo "$(GREEN)✅ Placeholder files created$(NC)"

# รอ GraphQL พร้อม
graphql-wait:
	@echo "$(YELLOW)⏳ Waiting for GraphQL endpoint...$(NC)"
	@echo "$(CYAN)Testing backend health first...$(NC)"
	@# รอ backend health check ผ่านก่อน
	@elapsed=0; \
    max_time=60; \
    while [ $$elapsed -lt $$max_time ]; do \
		if curl -sf http://localhost:5000/health >/dev/null 2>&1; then \
			echo "$(GREEN)✅ Backend health check passed ($$elapsed/$$max_time s)$(NC)"; \
			break; \
		fi; \
		printf "\r  Waiting for backend... $$elapsed/$$max_time s"; \
		sleep 5; \
		elapsed=$$((elapsed + 5)); \
	done; \
	if [ $$elapsed -ge $$max_time ]; then \
		echo ""; \
		echo "$(RED)❌ Backend health check timeout$(NC)"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(CYAN)Testing GraphQL endpoint...$(NC)"
	@# รอ GraphQL endpoint พร้อม
	@elapsed=0; \
	max_time=$(TIMEOUT_GRAPHQL); \
	while [ $$elapsed -lt $$max_time ]; do \
		if docker compose exec -T $(SERVICE_FRONTEND) sh -c '\
			curl -sf -X POST http://aspdotnetweb:5000/graphql \
			-H "Content-Type: application/json" \
			-H "X-Allow-Introspection: true" \
			-d "{\"query\":\"{__typename}\"}" >/dev/null 2>&1'; then \
			echo "$(GREEN)✅ GraphQL ready ($$elapsed/$$max_time s)$(NC)"; \
			exit 0; \
		fi; \
		printf "\r  Waiting for GraphQL... $$elapsed/$$max_time s"; \
		sleep 5; \
		elapsed=$$((elapsed + 5)); \
	done; \
	echo ""; \
	echo "$(YELLOW)⚠️  GraphQL timeout - will use placeholder files$(NC)"; \
	exit 0

graphql-download:
	@echo "$(BLUE)📥 Downloading GraphQL Schema$(NC)"
	@docker compose exec -T $(SERVICE_FRONTEND) bash -c '\
        set +e; \
        echo "Testing GraphQL connection..."; \
        if ! curl -sf -X POST http://aspdotnetweb:5000/graphql \
            -H "Content-Type: application/json" \
            -H "X-Allow-Introspection: true" \
            -d "{\"query\":\"{__typename}\"}" >/dev/null 2>&1; then \
            echo "❌ GraphQL endpoint not accessible"; \
            echo "⚠️  Using placeholder schema"; \
            npm run assure-files; \
            exit 0; \
        fi; \
        \
        echo "Running schema download script..."; \
        if timeout 60 bash ./scripts/download-schema.sh 2>&1 | tee /tmp/schema-download.log; then \
            if [ -f apollo/schema.graphql ] && [ -s apollo/schema.graphql ]; then \
                if grep -q "type Query" apollo/schema.graphql 2>/dev/null || \
                   grep -q "\"__schema\"" apollo/schema.graphql 2>/dev/null; then \
                    lines=$$(wc -l < apollo/schema.graphql 2>/dev/null || echo 0); \
                    echo "✅ Schema downloaded ($$lines lines)"; \
                    exit 0; \
                fi; \
            fi; \
        fi; \
        \
        echo "⚠️  Schema download failed/timeout"; \
        echo "📋 Last 15 lines:"; \
        tail -n 15 /tmp/schema-download.log 2>/dev/null || echo "(no log)"; \
        npm run assure-files; \
        exit 0'

# สร้าง GraphQL client
graphql-generate:
	@echo "$(BLUE)Generating GraphQL Client$(NC)"
	@docker compose exec -T $(SERVICE_FRONTEND) sh -c '\
        echo "Running codegen..."; \
		if npm run codegen 2>&1 | tee /tmp/codegen.log; then \
			echo ""; \
			echo "✅ GraphQL client generated successfully"; \
			\
			if [ -f apollo/generated/graphql.ts ]; then \
				size=$$(wc -c < apollo/generated/graphql.ts); \
				if [ $$size -gt 1000 ]; then \
					echo "✅ Generated files appear valid ($$size bytes)"; \
				else \
					echo "⚠️  Generated files may be incomplete ($$size bytes)"; \
				fi; \
			fi; \
			exit 0; \
		else \
			exit_code=$$?; \
			echo ""; \
			echo "⚠️  Codegen encountered issues (exit code: $$exit_code)"; \
			echo ""; \
			echo "📋 Last 20 lines of output:"; \
			tail -n 20 /tmp/codegen.log 2>/dev/null || cat /tmp/codegen.log; \
			echo ""; \
			echo "📝 Ensuring placeholder files exist..."; \
			npm run assure-files; \
			echo "⚠️  Using placeholder files"; \
			exit 0; \
		fi'
	@$(MAKE) graphql-check 

# ทดสอบ GraphQL
graphql-test:
	@echo "$(YELLOW)Testing GraphQL Endpoint...$(NC)"
	@echo ""
	@echo "$(CYAN)1️⃣  Testing backend health:$(NC)"
	@if curl -sf http://localhost:5000/health -o /tmp/health-test.json 2>/dev/null; then \
		echo "$(GREEN)  ✅ Backend health OK$(NC)"; \
		cat /tmp/health-test.json 2>/dev/null || echo "  (No response body)"; \
		rm -f /tmp/health-test.json; \
	else \
		echo "$(RED)  ❌ Backend health check failed$(NC)"; \
	fi
	@echo ""
	@echo "$(CYAN)2️⃣  Testing GraphQL from host:$(NC)"
	@if curl -sf -X POST http://localhost:5000/graphql \
		-H "Content-Type: application/json" \
		-H "X-Allow-Introspection: true" \
		-d '{"query":"{ __typename }"}' \
		-o /tmp/graphql-test.json 2>/dev/null; then \
		echo "$(GREEN)  ✅ Host connection OK$(NC)"; \
		cat /tmp/graphql-test.json | jq '.' 2>/dev/null || cat /tmp/graphql-test.json; \
		rm -f /tmp/graphql-test.json; \
	else \
		echo "$(RED)  ❌ Host connection failed$(NC)"; \
	fi
	@echo ""
	@echo "$(CYAN)3️⃣  Testing GraphQL from frontend container:$(NC)"
	@if docker compose exec -T $(SERVICE_FRONTEND) sh -c '\
		curl -sf -X POST http://aspdotnetweb:5000/graphql \
		-H "Content-Type: application/json" \
		-H "X-Allow-Introspection: true" \
		-d "{\"query\":\"{__typename}\"}"' 2>/dev/null | jq '.' 2>/dev/null; then \
		echo "$(GREEN)  ✅ Container connection OK$(NC)"; \
	else \
		echo "$(RED)  ❌ Container connection failed$(NC)"; \
	fi
	@echo ""

# ตรวจสอบ files
graphql-check:
	@echo "📝 Schema Status:"
	@echo "  • File: $(GRAPHQL_SCHEMA_FILE)"
	@echo "  • Mode: $$(grep -q _placeholder $(GRAPHQL_SCHEMA_FILE) && echo '🚧 Placeholder' || echo '✔️ Real schema')"
	@echo "  • Format: $$(file $(GRAPHQL_SCHEMA_FILE) | grep -q text && echo 'SDL' || echo 'JSON/Other')"

# แก้ไขปัญหา GraphQL
graphql-fix-safe:
	@echo "$(YELLOW)⚙️ Fixing GraphQL safely...$(NC)"
	@$(MAKE) graphql-assure
	@$(MAKE) graphql-wait || true
	@$(MAKE) graphql-download || true
	@$(MAKE) graphql-generate || true

# Watch mode for development
graphql-watch:
	@echo "$(BLUE)👀 Starting GraphQL Codegen Watch Mode$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to stop$(NC)"
	@echo ""
	@docker compose exec $(SERVICE_FRONTEND) npm run codegen:watch

# Validate GraphQL setup
graphql-validate:
	@docker compose exec $(SERVICE_FRONTEND) npx graphql-inspector validate \
        apollo/**/*.graphql apollo/schema.graphql || echo "⚠️ Schema validation failed or skipped"

# Complete GraphQL reset and setup
graphql-reset:
	@echo "$(RED)⚠️  Resetting GraphQL setup...$(NC)"
	@read -p "This will delete all GraphQL files. Continue? (y/N): " confirm; \
    if [ "$$confirm" != "y" ]; then \
        echo "Cancelled."; \
        exit 1; \
    fi
	@docker compose exec -T $(SERVICE_FRONTEND) sh -c '\
        rm -rf apollo/generated/* apollo/schema.graphql && \
        echo "🧹 Cleaned all GraphQL files"'
	@echo ""
	@$(MAKE) graphql-setup
	@echo ""
	@echo "$(GREEN)✅ GraphQL reset complete$(NC)"

graphql-status:
	@echo "$(BLUE)🔍 GraphQL Status Summary$(NC)"
	@$(MAKE) -s graphql-check
	@$(MAKE) -s graphql-validate

graphql-health:
	@echo -n "⏳ Checking GraphQL /health => "
	@curl -sf http://localhost:5000/health > /dev/null 2>&1 && echo "$(GREEN)OK$(NC)" || echo "$(RED)FAILED$(NC)"
	@echo -n "⏳ Checking GraphQL POST => "
	@curl -sf -X POST http://localhost:5000/graphql \
        -H "Content-Type: application/json" \
        -H "X-Allow-Introspection: true" \
        -d '{"query":"{__typename}"}' > /dev/null 2>&1 && echo "$(GREEN)OK$(NC)" || echo "$(RED)FAILED$(NC)"

# Show GraphQL info (helpful for debugging)
graphql-info:
	@echo "$(BLUE)ℹ️  GraphQL Configuration$(NC)"
	@echo ""
	@echo "$(YELLOW)Endpoints:$(NC)"
	@echo "  Internal: $(GRAPHQL_ENDPOINT)"
	@echo "  External: http://localhost:5000/graphql"
	@echo ""
	@echo "$(YELLOW)Timeouts:$(NC)"
	@echo "  Wait timeout: $(TIMEOUT_GRAPHQL)s"
	@echo ""
	@echo "$(YELLOW)Files:$(NC)"
	@echo "  Schema: apollo/schema.graphql"
	@echo "  Generated: apollo/generated/"
	@echo ""
	@$(MAKE) graphql-check

.PHONY: install-graphql-utilities
install-graphql-utilities:
	@echo "$(BLUE)Installing GraphQL Tools$(NC)"
	@timeout=30; counter=0; \
	until docker compose ps | grep -q "$(SERVICE_FRONTEND).*Up"; do \
        echo "  ⏳ Waiting for frontend container... ($$counter/$$timeout s)"; \
        sleep 2; counter=$$((counter+2)); \
    done
	@docker compose exec -T $(SERVICE_FRONTEND) sh -c '\
        npm install -D \
            graphql-json-to-sdl \
            @graphql-inspector/cli \
            graphql-cli \
        && echo "✅ Tools installed" || echo "$(RED)❌ Failed$(NC)"'

.PHONY: graphql-clean
graphql-clean:
	@echo "$(BLUE)🧹 Cleaning GraphQL generated files...$(NC)"
	@docker compose exec -T $(SERVICE_FRONTEND) rm -rf apollo/generated/* || true

.PHONY: graphql-schema-format
graphql-schema-format:
	@if [ -f "$(GRAPHQL_SCHEMA_FILE)" ]; then \
        echo "$(BLUE)📋 Formatting schema...$(NC)"; \
        npx prettier --write "$(GRAPHQL_SCHEMA_FILE)"; \
    fi

# ╔═══════════════════════════════════════════════════════════╗
# ║                        DATABASE                           ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: db-test db-wait db-shell db-migration

db-test: check-password
	@PASSWORD=$$(cat $(FILE_PASSWORD)); \
    docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P "$$PASSWORD" \
        -Q "SELECT @@VERSION;" -C \
        && echo "$(GREEN)✅ OK$(NC)" || echo "$(RED)❌ Failed$(NC)"

db-wait: check-password
	@echo "$(YELLOW)⏳ Waiting for SQL Server...$(NC)"
	@PASSWORD=$$(cat $(FILE_PASSWORD)); \
    elapsed=0; \
    while [ $$elapsed -lt $(TIMEOUT_DB) ]; do \
        if docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd \
            -S localhost -U sa -P "$$PASSWORD" \
            -Q "SELECT 1" -C -b >/dev/null 2>&1; then \
            echo "$(GREEN)✅ SQL Server ready ($$elapsed/$(TIMEOUT_DB)s)$(NC)"; \
            exit 0; \
        fi; \
        printf "\r  Waiting... $$elapsed/$(TIMEOUT_DB)s"; \
        sleep 5; \
        elapsed=$$((elapsed + 5)); \
    done; \
    echo "$(RED)❌ Timeout$(NC)"; \
    exit 1

db-shell: check-password
	@PASSWORD=$$(cat $(FILE_PASSWORD)); \
    docker exec -it sqlserver /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P "$$PASSWORD" -C

db-migration:
	@[ -n "$(NAME)" ] || { echo "$(RED)Usage: make db-migration NAME=xxx$(NC)"; exit 1; }
	@MIGRATION_NAME=$(NAME) ADD_NEW_MIGRATION=true \
        docker compose --profile migration up migration-db
	@echo "$(GREEN)✅ Migration created: $(NAME)$(NC)"

# ╔═══════════════════════════════════════════════════════════╗
# ║                       MONITORING                          ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: logs status health wait-for-health show-urls

logs:
	@docker compose logs -f

status:
	@echo "$(BLUE)╔═══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║          Service Status                                    ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════════════╝$(NC)"
	@docker compose ps

health:
	@echo "$(YELLOW)Checking Health Endpoints...$(NC)"
	@for service in "ASP.NET:http://localhost:5000/health" \
                    "Nginx:http://localhost:80/health" \
                    "Vite:http://localhost:5173" \
                    "SSR:http://localhost:13714/health"; do \
        name=$${service%%:*}; \
        url=$${service#*:}; \
        if curl -sf "$$url" >/dev/null 2>&1; then \
            echo "  ✅ $$name"; \
        else \
            echo "  ❌ $$name"; \
        fi; \
    done

wait-for-health:
	@echo "$(YELLOW)⏳ Waiting for services to be healthy...$(NC)"
	@elapsed=0; \
	while [ $$elapsed -lt $(TIMEOUT_HEALTH) ]; do \
        healthy=$$(docker compose ps | grep -c "healthy" 2>/dev/null || echo "0"); \
        if [ $$healthy -ge 2 ]; then \
            echo "$(GREEN)✅ Services healthy ($$elapsed/$(TIMEOUT_HEALTH)s)$(NC)"; \
            exit 0; \
        fi; \
        printf "\r  Healthy: $$healthy ($$elapsed/$(TIMEOUT_HEALTH)s)"; \
        sleep 5; \
        elapsed=$$((elapsed + 5)); \
    done; \
    echo "$(RED)❌ Timeout$(NC)"; \
    exit 1

show-urls:
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║          Service URLs                                      ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════╝$(NC)"
	@echo "  • Frontend:  $(BLUE)http://localhost:5173$(NC)"
	@echo "  • Backend:   $(BLUE)http://localhost:5000$(NC)"
	@echo "  • GraphQL:   $(BLUE)http://localhost:5000/graphql$(NC)"
	@echo "  • Swagger:   $(BLUE)http://localhost:5000/swagger$(NC)"
	@echo "  • NginX:     $(BLUE)http://localhost:8080$(NC)"
	@echo "  • SSR:       $(BLUE)http://localhost:13714$(NC)"

# ╔═══════════════════════════════════════════════════════════╗
# ║                       MAINTENANCE                         ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: clean rebuild reset fix-permissions remove-volumes

clean:
	@docker compose $(COMPOSE_PROFILES) down
	@echo "$(GREEN)✅ Cleaned$(NC)"

rebuild: clean setup-scripts fix-line-endings build

reset:
	@echo "$(RED)⚠️  WARNING: This deletes EVERYTHING!$(NC)"
	@echo "$(YELLOW)This will remove:$(NC)"
	@echo "  • All containers"
	@echo "  • All volumes (database data)"
	@echo "  • All migrations"
	@read -p "Type 'YES' to confirm: " confirm; \
    [ "$$confirm" = "YES" ] || exit 1
	@docker compose $(COMPOSE_PROFILES) down -v
	@rm -rf $(DIR_MIGRATIONS)/*.cs 2>/dev/null || true
	@echo "$(GREEN)✅ Reset complete$(NC)"
	@echo "$(YELLOW)Run: make first-run$(NC)"

fix-permissions:
	@echo "$(BLUE)Fixing Permissions$(NC)"
	@docker run --rm --user root \
        -v $(PROJECT_NAME)_rssdata:/data \
        -v $(PROJECT_NAME)_rssdata-logs:/logs \
        -v $(PROJECT_NAME)_db-backups:/backups \
        alpine:latest sh -c '\
        chown -R 10001:0 /data /logs /backups && \
        chmod -R 777 /data /logs /backups'
	@echo "$(GREEN)✅ Permissions fixed$(NC)"

remove-volumes: clean
	@echo "$(RED)🔥 Removing all project volumes associated with $(PROJECT_NAME)...$(NC)"
	@docker volume ls -q -f name=$(PROJECT_NAME) | xargs -r docker volume rm
	@echo "$(GREEN)✅ All project volumes removed successfully.$(NC)"

# ╔═══════════════════════════════════════════════════════════╗
# ║                         UTILITIES                         ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: check-host-tools debug quick

check-host-tools:
	@echo "$(YELLOW)Checking Host Tools...$(NC)"
	@for tool in bash docker docker-compose make curl; do \
        if command -v $$tool >/dev/null 2>&1; then \
            version=$$($$tool --version 2>&1 | head -1); \
            echo "  ✅ $$tool - $$version"; \
        else \
            echo "  ❌ $$tool - MISSING"; \
        fi; \
    done
	@for tool in dos2unix jq; do \
        if command -v $$tool >/dev/null 2>&1; then \
            echo "  ✅ $$tool (optional)"; \
        else \
            echo "  ⚠️  $$tool (optional, not installed)"; \
        fi; \
    done

debug:
	@echo "$(BLUE)╔═══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║          Debug Information                                 ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════════════╝$(NC)"
	@echo "$(YELLOW)OS:$(NC) $(UNAME_S)"
	@echo "$(YELLOW)Project:$(NC) $(PROJECT_NAME)"
	@echo "$(YELLOW)GraphQL Endpoint:$(NC) $(GRAPHQL_ENDPOINT)"
	@echo "$(YELLOW)Timeouts:$(NC) DB=$(TIMEOUT_DB)s, GraphQL=$(TIMEOUT_GRAPHQL)s, Health=$(TIMEOUT_HEALTH)s"
	@echo ""
	@$(MAKE) status
	@echo ""
	@$(MAKE) health

quick:
	@$(MAKE) -s check-host-tools
	@$(MAKE) -s graphql-status
	@$(MAKE) -s graphql-health

.PHONY: ci-check

ci-check:
	@$(MAKE) graphql-check
	@$(MAKE) graphql-validate
	@$(MAKE) type-check
	@$(MAKE) lint

# ╔═══════════════════════════════════════════════════════════╗
# ║                    DEVELOPMENT TOOLS                      ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: dev-reset dev-clean npm-install npm-update type-check lint

# ✅ Reset development environment
dev-reset:
	@echo "$(RED)⚠️  Resetting development environment...$(NC)"
	@docker compose down
	@docker compose exec -T $(SERVICE_FRONTEND) sh -c '\
		rm -rf node_modules/.vite node_modules/.cache apollo/generated/* && \
		echo "✅ Caches cleared"'
	@$(MAKE) graphql-assure
	@docker compose up -d $(SERVICE_FRONTEND)
	@echo "$(GREEN)✅ Development environment reset$(NC)"

# ✅ Clean frontend caches
dev-clean:
	@echo "$(BLUE)🧹 Cleaning frontend caches...$(NC)"
	@docker compose exec -T $(SERVICE_FRONTEND) sh -c '\
		rm -rf node_modules/.vite node_modules/.cache .turbo dist && \
		echo "✅ Caches cleaned"'

# ✅ Install/update npm packages
npm-install:
	@echo "$(BLUE)📦 Installing npm packages...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm install

npm-update:
	@echo "$(BLUE)📦 Updating npm packages...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm update

# ✅ TypeScript type checking
type-check:
	@echo "$(BLUE)🔍 Running TypeScript type check...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run type-check

# ✅ Lint code
lint:
	@echo "$(BLUE)🔍 Running linter...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run lint

lint-fix:
	@echo "$(BLUE)🔧 Fixing linting issues...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run lint:fix

# ╔═══════════════════════════════════════════════════════════╗
# ║                    TESTING & DEBUGGING                    ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: test test-ui test-coverage test-graphql-query debug-env

# ✅ Run tests
test:
	@echo "$(BLUE)🧪 Running tests...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run test

test-ui:
	@echo "$(BLUE)🧪 Running tests with UI...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run test:ui

test-coverage:
	@echo "$(BLUE)📊 Running tests with coverage...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run test:coverage

# ✅ Test GraphQL query
test-graphql-query:
	@echo "$(BLUE)Testing GraphQL query...$(NC)"
	@read -p "Enter query (e.g., {__typename}): " query; \
	curl -X POST http://localhost:5000/graphql \
		-H "Content-Type: application/json" \
		-H "X-Allow-Introspection: true" \
		-d "{\"query\":\"$$query\"}" | jq '.'

# ✅ Debug environment
debug-env:
	@echo "$(BLUE)╔═══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║          Environment Variables                             ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)Frontend Container:$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) env | grep -E '^(VITE_|NODE_|npm_)' | sort
	@echo ""
	@echo "$(YELLOW)Backend Container:$(NC)"
	@docker compose exec $(SERVICE_ASPNETCORE) env | grep -E '^(ASPNETCORE_|DATABASE_)' | sort

# ╔═══════════════════════════════════════════════════════════╗
# ║                    PERFORMANCE & OPTIMIZATION             ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: analyze-bundle check-size optimize-images

# ✅ Analyze bundle size
analyze-bundle:
	@echo "$(BLUE)📊 Analyzing bundle size...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run build -- --mode analyze

# ✅ Check frontend size
check-size:
	@echo "$(BLUE)📏 Checking build size...$(NC)"
	@if [ -d "vite-ui/wwwroot/volume" ]; then \
		du -sh vite-ui/wwwroot/volume; \
		echo ""; \
		echo "Largest files:"; \
		find vite-ui/wwwroot/volume -type f -exec du -h {} + | sort -rh | head -10; \
	else \
		echo "$(YELLOW)⚠️  Build directory not found. Run 'make build' first.$(NC)"; \
	fi

# ╔═══════════════════════════════════════════════════════════╗
# ║                    BACKUP & RESTORE                       ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: backup-db restore-db backup-volumes

# Backup database
backup-db: check-password
	@echo "$(BLUE)💾 Backing up database...$(NC)"
	@mkdir -p ./backups
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
	PASSWORD=$$(cat $(FILE_PASSWORD)); \
	docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd \
		-S localhost -U sa -P "$$PASSWORD" \
		-Q "BACKUP DATABASE [$(DATABASE_NAME)] TO DISK = '/var/opt/mssql/backups/backup_$$TIMESTAMP.bak'" -C \
		&& echo "$(GREEN)✅ Backup created: backup_$$TIMESTAMP.bak$(NC)" \
		|| echo "$(RED)❌ Backup failed$(NC)"

# Restore database
restore-db: check-password
	@echo "$(YELLOW)Available backups:$(NC)"
	@docker exec sqlserver ls -lh /var/opt/mssql/backups/
	@read -p "Enter backup filename: " backup; \
	if [ -n "$$backup" ]; then \
		PASSWORD=$$(cat $(FILE_PASSWORD)); \
		docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd \
			-S localhost -U sa -P "$$PASSWORD" \
			-Q "RESTORE DATABASE [$(DATABASE_NAME)] FROM DISK = '/var/opt/mssql/backups/$$backup' WITH REPLACE" -C \
			&& echo "$(GREEN)✅ Database restored from $$backup$(NC)" \
			|| echo "$(RED)❌ Restore failed$(NC)"; \
	else \
		echo "$(RED)No backup specified$(NC)"; \
	fi

# ╔═══════════════════════════════════════════════════════════╗
# ║                    QUICK FIXES                            ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: fix-postcss fix-tailwind fix-node-modules

# ✅ Fix PostCSS configuration
fix-postcss:
	@echo "$(BLUE)🔧 Fixing PostCSS configuration...$(NC)"
	@docker compose exec -T $(SERVICE_FRONTEND) sh -c '\
		cat > postcss.config.cjs << "EOF" \
module.exports = { \
    plugins: [ \
        require("postcss-import"), \
        require("tailwindcss"), \
        require("autoprefixer"), \
        require("cssnano")({ preset: "default" }), \
    ], \
}; \
EOF \
		&& echo "✅ PostCSS config fixed"'

# ✅ Fix Tailwind configuration
fix-tailwind:
	@echo "$(BLUE)🔧 Validating Tailwind configuration...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npx tailwindcss --help > /dev/null 2>&1 \
		&& echo "$(GREEN)✅ Tailwind OK$(NC)" \
		|| echo "$(RED)❌ Tailwind issue detected$(NC)"

# ✅ Reinstall node_modules
fix-node-modules:
	@echo "$(RED)⚠️  Reinstalling node_modules...$(NC)"
	@docker compose exec -T $(SERVICE_FRONTEND) sh -c '\
		rm -rf node_modules package-lock.json && \
		npm install --legacy-peer-deps && \
		echo "✅ node_modules reinstalled"'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#             QUICK DEBUGGING & TROUBLESHOOTING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

.PHONY: quick-check debug-graphql-full logs-graphql restart-graphql

quick-check:
	@echo "$(BLUE)🔍 Quick System Check$(NC)"
	@echo ""
	@echo "$(YELLOW)1️⃣  Backend Health:$(NC)"
	@curl -sf http://localhost:5000/health 2>/dev/null \
		&& echo "  ✅ Backend OK" \
		|| echo "  ❌ Backend DOWN"
	@echo ""
	@echo "$(YELLOW)2️⃣  GraphQL Endpoint:$(NC)"
	@curl -sf -X POST http://localhost:5000/graphql \
		-H "Content-Type: application/json" \
		-H "X-Allow-Introspection: true" \
		-d '{"query":"query{__schema{queryType{name}}}"}' 2>/dev/null \
		&& echo "  ✅ GraphQL OK" \
		|| echo "  ❌ GraphQL FAILED"
	@echo ""
	@echo "$(YELLOW)3️⃣  Frontend Container:$(NC)"
	@docker compose ps $(SERVICE_FRONTEND) | grep -q "Up" \
		&& echo "  ✅ Frontend Running" \
		|| echo "  ❌ Frontend Stopped"
	@echo ""
	@echo "$(YELLOW)4️⃣  Schema File:$(NC)"
	@if docker compose exec -T $(SERVICE_FRONTEND) test -f apollo/schema.graphql 2>/dev/null; then \
		if docker compose exec -T $(SERVICE_FRONTEND) grep -q "_placeholder" apollo/schema.graphql 2>/dev/null; then \
			echo "  ⚠️  Placeholder Schema"; \
		else \
			lines=$$(docker compose exec -T $(SERVICE_FRONTEND) wc -l < apollo/schema.graphql 2>/dev/null | tr -d '[:space:]'); \
			echo "  ✅ Real Schema ($$lines lines)"; \
		fi; \
	else \
		echo "  ❌ Schema Missing"; \
	fi
	@echo ""
	@echo "$(YELLOW)5️⃣  Generated Files:$(NC)"
	@for file in graphql.ts index.ts gql.ts; do \
		if docker compose exec -T $(SERVICE_FRONTEND) test -f "apollo/generated/$$file" 2>/dev/null; then \
			size=$$(docker compose exec -T $(SERVICE_FRONTEND) wc -c < "apollo/generated/$$file" 2>/dev/null | tr -d '[:space:]'); \
			if [ $$size -gt 1000 ]; then \
				echo "  ✅ $$file"; \
			else \
				echo "  ⚠️  $$file (placeholder)"; \
			fi; \
		else \
			echo "  ❌ $$file (missing)"; \
		fi; \
	done

# ✅ Full GraphQL debugging
debug-graphql-full:
	@echo "$(BLUE)╔═══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║          Full GraphQL Debug Report                        ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@$(MAKE) quick-check
	@echo ""
	@echo "$(YELLOW)🔍 Backend Container Logs (last 30 lines):$(NC)"
	@docker compose logs --tail=30 $(SERVICE_ASPNETCORE) | grep -i graphql || echo "  No GraphQL logs found"
	@echo ""
	@echo "$(YELLOW)🔍 Frontend Container Logs (last 30 lines):$(NC)"
	@docker compose logs --tail=30 $(SERVICE_FRONTEND) | grep -E "(GraphQL|schema|codegen)" || echo "  No relevant logs found"
	@echo ""
	@echo "$(YELLOW)🔍 Environment Variables (Frontend):$(NC)"
	@docker compose exec -T $(SERVICE_FRONTEND) env | grep -E "^(VITE_GRAPHQL|WAIT_FOR)" | sort

# ✅ Live GraphQL logs
logs-graphql:
	@echo "$(YELLOW)📜 Following GraphQL-related logs...$(NC)"
	@echo "$(CYAN)Press Ctrl+C to stop$(NC)"
	@docker compose logs -f $(SERVICE_ASPNETCORE) $(SERVICE_FRONTEND) | grep -i --line-buffered "graphql\|schema\|codegen"

# ✅ Restart frontend และ regenerate GraphQL
restart-graphql:
	@echo "$(YELLOW)🔄 Restarting frontend and regenerating GraphQL...$(NC)"
	@docker compose restart $(SERVICE_FRONTEND)
	@sleep 5
	@$(MAKE) graphql-wait
	@$(MAKE) graphql-download
	@$(MAKE) graphql-generate
	@echo "$(GREEN)✅ Complete!$(NC)"
	@$(MAKE) quick-check

# ✅ Force regenerate (แม้ backend ไม่พร้อม)
graphql-force-placeholder:
	@echo "$(YELLOW)📝 Forcing placeholder files...$(NC)"
	@docker compose exec -T $(SERVICE_FRONTEND) npm run assure-files
	@docker compose restart $(SERVICE_FRONTEND)
	@echo "$(GREEN)✅ Placeholder files created and frontend restarted$(NC)"

# ✅ Test GraphQL query ง่ายๆ
graphql-query:
	@echo "$(BLUE)Testing GraphQL with simple query...$(NC)"
	@curl -X POST http://localhost:5000/graphql \
		-H "Content-Type: application/json" \
		-H "X-Allow-Introspection: true" \
		-d '{"query":"query { __typename }"}' \
		| jq '.' 2>/dev/null || cat

# ✅ Download schema manually
graphql-download-manual:
	@echo "$(BLUE)Manually downloading schema...$(NC)"
	@docker compose exec -T $(SERVICE_FRONTEND) bash -c '\
		curl -X POST http://aspdotnetweb:5000/graphql \
			-H "Content-Type: application/json" \
			-H "X-Allow-Introspection: true" \
			-d @- <<EOF | tee apollo/schema.json | jq . \
{"query":"query IntrospectionQuery { __schema { queryType { name } mutationType { name } types { kind name description fields(includeDeprecated: true) { name description args { name description type { ...TypeRef } defaultValue } type { ...TypeRef } isDeprecated deprecationReason } inputFields { name description type { ...TypeRef } defaultValue } interfaces { ...TypeRef } enumValues(includeDeprecated: true) { name description isDeprecated deprecationReason } possibleTypes { ...TypeRef } } directives { name description locations args { name description type { ...TypeRef } defaultValue } } } } fragment TypeRef on __Type { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name } } } } } } } }"} \
EOF'

# ✅ One-liner: ทดสอบทุกอย่าง
test-all: quick-check health graphql-test graphql-check

# ✅ Emergency reset
emergency-reset:
	@echo "$(RED)⚠️  EMERGENCY RESET - This will restart everything!$(NC)"
	@read -p "Continue? (yes/NO): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo "$(YELLOW)1. Stopping all services...$(NC)"; \
		docker compose down; \
		echo "$(YELLOW)2. Cleaning caches...$(NC)"; \
		docker compose exec -T $(SERVICE_FRONTEND) rm -rf node_modules/.cache apollo/generated/* 2>/dev/null || true; \
		echo "$(YELLOW)3. Starting services...$(NC)"; \
		docker compose up -d; \
		echo "$(YELLOW)4. Waiting for health...$(NC)"; \
		sleep 30; \
		$(MAKE) wait-for-health; \
		echo "$(YELLOW)5. Regenerating GraphQL...$(NC)"; \
		$(MAKE) graphql-setup; \
		echo "$(GREEN)✅ Emergency reset complete!$(NC)"; \
		$(MAKE) quick-check; \
	else \
		echo "Cancelled."; \
	fi

# ╔═══════════════════════════════════════════════════════════╗
# ║                    DOCUMENTATION                          ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: documents-api documents-graphql

# ✅ Generate API documentation
documents-api:
	@echo "$(BLUE)📚 Generating API documentation...$(NC)"
	@docker compose exec $(SERVICE_FRONTEND) npm run generate-all

# ✅ View GraphQL schema documentation
documents-graphql:
	@echo "$(BLUE)📖 GraphQL Schema:$(NC)"
	@echo ""
	@docker compose exec -T $(SERVICE_FRONTEND) cat apollo/schema.graphql | head -n 50
	@echo ""
	@echo "$(YELLOW)Full schema: http://localhost:5000/graphql$(NC)"

# ╔═══════════════════════════════════════════════════════════╗
# ║                    FIREWALL MANAGEMENT                    ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: firewall-enable firewall-disable firewall-status firewall-sync firewall-ssh firewall-ssh-status

# Enable firewall rules
firewall-enable:
	@echo "$(CYAN)🔥 Enabling firewall rules...$(NC)"
	@if command -v firewall-cmd >/dev/null 2>&1; then \
        echo "$(YELLOW)Configuring firewalld (Linux)...$(NC)"; \
        sudo bash scripts/firewall/linux/firewalld-setup.sh enable development; \
        sudo bash scripts/firewall/linux/selinux-setup.sh enable; \
    else \
        echo "$(YELLOW)Linux firewall tools not found$(NC)"; \
    fi
	@echo "$(GREEN)✅ Firewall configured$(NC)"

# Disable firewall
firewall-disable:
	@echo "$(YELLOW)⏸️  Disabling firewall...$(NC)"
	@if command -v firewall-cmd >/dev/null 2>&1; then \
        sudo systemctl stop firewalld; \
    fi

# Show firewall status
firewall-status:
	@echo "$(CYAN)📊 Firewall Status$(NC)"
	@if command -v firewall-cmd >/dev/null 2>&1; then \
        sudo firewall-cmd --list-all; \
        sudo semanage port -l | grep http_port_t; \
    else \
        echo "$(YELLOW)Firewall not configured$(NC)"; \
    fi

# Sync firewall across platforms (if using WSL2)
firewall-sync:
	@echo "$(CYAN)🔄 Syncing firewall rules...$(NC)"
	@bash scripts/firewall/linux/firewalld-setup.sh enable all

firewall-ssh:
	@echo "$(CYAN)🔐 Configuring SSH Firewall...$(NC)"
	@powershell -ExecutionPolicy Bypass -File scripts/firewall/windows/openssh-firewall.ps1 -Action Enable -SecurityLevel Medium

firewall-ssh-status:
	@echo "$(CYAN)📊 SSH Firewall Status$(NC)"
	@powershell -ExecutionPolicy Bypass -File scripts/firewall/windows/openssh-firewall.ps1 -Action Status

# ╔═══════════════════════════════════════════════════════════╗
# ║                    SSH MANAGEMENT                         ║
# ╚═══════════════════════════════════════════════════════════╝

.PHONY: ssh-install ssh-keygen ssh-status ssh-harden

ssh-install:
	@echo "$(CYAN)📦 Installing OpenSSH...$(NC)"
	@sudo bash scripts/setup/install-openssh.sh

ssh-keygen:
	@echo "$(CYAN)🔑 Generating SSH keys...$(NC)"
	@bash scripts/setup/manage-ssh-keys.sh generate

ssh-status:
	@echo "$(CYAN)📊 SSH Status$(NC)"
	@sudo systemctl status sshd --no-pager
	@echo "\n$(YELLOW)Open Ports:$(NC)"
	@sudo ss -tlnp | grep sshd

ssh-harden:
	@echo "$(CYAN)🔒 Hardening SSH...$(NC)"
	@sudo bash scripts/setup/ssh-hardening.sh

# Backward compatibility
.PHONY: wait-for-db wait-for-graphql test-db test-graphql
.PHONY: generate-graphql-safe check-graphql fix-all-graphql

wait-for-db: db-wait
wait-for-graphql: graphql-wait
test-db: db-test
test-graphql: graphql-test
generate-graphql-safe: graphql-generate
check-graphql: graphql-check
fix-all-graphql: graphql-fix
migration: db-migration