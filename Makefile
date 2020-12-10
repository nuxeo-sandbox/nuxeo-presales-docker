NUXEO_IMAGE := "docker.packages.nuxeo.com/nuxeo/nuxeo:latest"
COMPOSE_DIR := .

Dockerfile:
	NUXEO_IMAGE=$(NUXEO_IMAGE) XVAR='$$' envsubst < Dockerfile.in > Dockerfile

build:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml build

start:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml up --detach

restart:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml restart

logs:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml logs -f

ps:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml ps

stop:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml stop

down:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml down

rm:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml rm --force --stop nuxeo

new: | rm start

clean:
	docker-compose --file $(COMPOSE_DIR)/docker-compose.yml down --volumes --rmi local --remove-orphans
