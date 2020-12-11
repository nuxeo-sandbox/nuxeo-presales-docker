NUXEO_IMAGE := "docker.packages.nuxeo.com/nuxeo/nuxeo:latest"
ELASTIC_VERSION := "7.9.3"
COMPOSE_DIR := .
SERVICE := 

Dockerfile: 
	NUXEO_IMAGE=$(NUXEO_IMAGE) XVAR='$$' envsubst < Dockerfile.in > Dockerfile

in/Dockerfile:
	ELASTIC_VERSION=$(ELASTIC_VERSION) XVAR='$$' envsubst < es/Dockerfile.in > es/Dockerfile

dockerfiles: Dockerfile in/Dockerfile

build:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml build $(SERVICE)

start:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml up --detach $(SERVICE)

restart:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml restart $(SERVICE)

logs:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml logs -f $(SERVICE)

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
