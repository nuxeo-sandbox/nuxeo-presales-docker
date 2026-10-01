.DEFAULT_GOAL := status
.PHONY: pull build pullbuild rebuild start exec restart logs status ps stop down rm new clean

COMPOSE_DIR := .
SERVICE :=
COMMAND :=

pull:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml pull $(SERVICE)

# CACHEBUST forces the Studio/Hyland package install layer (Studio SNAPSHOTs
# keep the same version, so Docker can't otherwise tell the project changed)
# while reusing the cached OS/RPM layers. For a full from-scratch build use
# `make clean`.
build:
	CACHEBUST=$(shell date +%s) docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml build $(SERVICE)

# Like build, but also pull a newer base image; useful with floating tags like `2025` or `latest`.
pullbuild:
	CACHEBUST=$(shell date +%s) docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml build --pull $(SERVICE)

# Backwards-compatible alias; build now always busts the package layer, so rebuild is redundant.
rebuild: build

up:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml up --detach $(SERVICE)

exec:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml exec $(SERVICE) $(COMMAND)

restart:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml restart $(SERVICE)

# For a single service, show only the current session's logs. If no service is
# specified, show all logs.
logs:
	@dc="docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml"; \
	if [ -n "$(SERVICE)" ]; then \
		since=$$(docker inspect -f '{{.State.StartedAt}}' $$($$dc ps -aq $(SERVICE)) 2>/dev/null); \
		$$dc logs -f --since "$${since:-1970-01-01T00:00:00Z}" $(SERVICE); \
	else \
		$$dc logs -f; \
	fi

status: | info ps

info:
	$(COMPOSE_DIR)/info.sh $(COMPOSE_DIR)

ps:
	@docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml ps

start:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml start $(SERVICE)

stop:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml stop $(SERVICE)

down:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml down $(SERVICE)

rm:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml rm --force --stop $(SERVICE)

new: | rm up

clean:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml down --volumes --rmi local --remove-orphans
