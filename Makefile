INSTALL_DIRECTORY ?= $(HOME)/.local/bin

build:
	swift build --configuration release

install: build
	mkdir -p $(INSTALL_DIRECTORY)
	install -m 755 .build/release/monkeys $(INSTALL_DIRECTORY)/monkeys

check: build
	python3 tools/check-skill.py .build/release/monkeys
	python3 tools/check-examples.py .build/release/monkeys
	python3 tools/check-plugin.py
	python3 tools/check-release-notes.py
	claude plugin validate .

picture: install
	python3 tools/render-terminal-svg.py terminal.svg

clean:
	swift package clean

deploy:
	cd docs && DEPLOY_TARGET=site bun run build
	cd docs && monkeys run wrangler pages deploy build/client --project-name monkeys --branch main
	cd docs && bun run build
	cd docs && monkeys run wrangler pages deploy build/client --project-name monkeys-docs --branch main

.PHONY: build install check picture clean deploy
