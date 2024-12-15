set dotenv-load

default: clear fmt
	docker compose up -d --build --remove-orphans

up: clear fmt
	docker compose up -d --build --remove-orphans

down: clear
	docker compose down

clear:
	clear

pull: clear fmt
	docker compose pull

restart: clear fmt
	docker compose restart

fmt: 
	dprint fmt
