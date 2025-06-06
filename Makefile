.DEFAULT_GOAL := status
.PHONY: pull build pullbuild rebuild start exec restart logs vilog status ps stop down rm new clean

COMPOSE_DIR := .
SERVICE :=
COMMAND :=

pull:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml pull $(SERVICE)

build:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml build $(SERVICE)

# Always attempt to pull a newer version of the image; useful with wrapper tags like `2023` or `latest`.
pullbuild:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml build --pull $(SERVICE)

# Build without cache; necessary when building with Studio SNAPSHOTS because Docker has no way to know the Studio project has changed.
rebuild:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml build --pull --no-cache $(SERVICE)

up:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml up --detach $(SERVICE)

exec:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml exec $(SERVICE) $(COMMAND)

restart:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml restart $(SERVICE)

logs:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml logs -f $(SERVICE)

vilog:
	docker compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml exec nuxeo vi /var/log/nuxeo/server.log

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
