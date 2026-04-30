set dotenv-load

compose := if `command -v docker 2>/dev/null` != "" { "docker compose" } else { "podman compose" }

default: up

up: clear git-pull
	{{ compose }} up -d --build --remove-orphans

down: clear
	{{ compose }} down

clear:
	clear

pull: clear
	{{ compose }} pull

restart: clear
	{{ compose }} restart

fmt: 
	dprint fmt

git-pull:
	git pull
