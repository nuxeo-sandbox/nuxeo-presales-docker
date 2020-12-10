NUXEO_IMAGE := "docker.packages.nuxeo.com/nuxeo/nuxeo:latest"
COMPOSE_DIR := .

Dockerfile:
	NUXEO_IMAGE=$(NUXEO_IMAGE) XVAR='$$' envsubst < Dockerfile.in > Dockerfile

build:
	docker-compose --project-directory $(COMPOSE_DIR) build

start:
	docker-compose --project-directory $(COMPOSE_DIR) up --detach

restart:
	docker-compose --project-directory $(COMPOSE_DIR) restart

logs:
	docker-compose --project-directory $(COMPOSE_DIR) logs -f

ps:
	docker-compose --project-directory $(COMPOSE_DIR) ps

stop:
	docker-compose --project-directory $(COMPOSE_DIR) stop

down:
	docker-compose --project-directory $(COMPOSE_DIR) down

clean:
	docker-compose --project-directory $(COMPOSE_DIR) down --volumes --rmi local --remove-orphans
