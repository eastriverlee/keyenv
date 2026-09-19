INSTALL_DIRECTORY ?= $(HOME)/.local/bin

build:
	swift build --configuration release

install: build
	mkdir -p $(INSTALL_DIRECTORY)
	install -m 755 .build/release/monkeys $(INSTALL_DIRECTORY)/monkeys

check: build
	python3 tools/check-skill.py .build/release/monkeys
	claude plugin validate .

picture: install
	python3 tools/render-terminal-svg.py terminal.svg

clean:
	swift package clean

.PHONY: build install check picture clean
