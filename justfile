set dotenv-load

default: up

up: clear git-pull
	podman compose up -d --build --remove-orphans

down: clear
	podman compose down

clear:
	clear

pull: clear 
	podman compose pull

restart: clear 
	podman compose restart

fmt: 
	dprint fmt

git-pull:
	git pull
