.DEFAULT_GOAL := status
.PHONY: pull build rebuild start exec restart logs vilog status ps stop down rm new clean

NUXEO_IMAGE := "docker.packages.nuxeo.com/nuxeo/nuxeo:latest"
ELASTIC_VERSION := "7.9.3"
COMPOSE_DIR := .
SERVICE := 
COMMAND := 

Dockerfile: 
	NUXEO_IMAGE=$(NUXEO_IMAGE) XVAR='$$' envsubst < Dockerfile.in > Dockerfile

es/Dockerfile:
	ELASTIC_VERSION=$(ELASTIC_VERSION) XVAR='$$' envsubst < es/Dockerfile.in > es/Dockerfile

dockerfiles: Dockerfile es/Dockerfile

pull:
	docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml pull $(SERVICE)

build:
	docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml build $(SERVICE)

rebuild: | pull build

up:
	docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml up --detach $(SERVICE)

exec:
	docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml exec $(SERVICE) $(COMMAND)

restart:
	docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml restart $(SERVICE)

logs:
	docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml logs -f $(SERVICE)

vilog:
	docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml exec nuxeo vi /var/log/nuxeo/server.log

status: | info ps

info:
	$(COMPOSE_DIR)/info.sh $(COMPOSE_DIR)

ps:
	@docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml ps

start:
	docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml start $(SERVICE)

stop:
	docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml stop $(SERVICE)

down:
	docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml down $(SERVICE)

rm:
	docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml rm --force --stop $(SERVICE)

new: | rm start

clean:
	docker-compose --project-directory $(COMPOSE_DIR) --file $(COMPOSE_DIR)/docker-compose.yml down --volumes --rmi local --remove-orphans
