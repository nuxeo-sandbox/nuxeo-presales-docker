.DEFAULT_GOAL := ps

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
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml pull $(SERVICE)

build:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml build $(SERVICE)

rebuild: | pull build

start:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml up --detach $(SERVICE)

exec:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml exec $(SERVICE) $(COMMAND)

restart:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml restart $(SERVICE)

logs:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml logs -f $(SERVICE)

vilog:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml exec nuxeo vi /var/log/nuxeo/server.log

status: ps

ps:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml ps

stop:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml stop $(SERVICE)

down:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml down $(SERVICE)

rm:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml rm --force --stop nuxeo

new: | rm start

clean:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml down --volumes --rmi local --remove-orphans
