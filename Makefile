build:
	docker-compose build

start:
	docker-compose up --detach

restart:
	docker-compose restart

logs:
	docker-compose logs -f

ps:
	docker-compose ps

stop:
	docker-compose stop

down:
	docker-compose down

clean:
	docker-compose down --volumes --rmi local --remove-orphans
