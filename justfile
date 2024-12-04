set dotenv-load

default: clear
	docker compose up -d --build --remove-orphans

up: clear
	docker compose up -d --build --remove-orphans

down: clear
	docker compose down

clear:
	clear

pull: clear
	docker compose pull

restart: clear
	docker compose restart
