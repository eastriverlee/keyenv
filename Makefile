INSTALL_DIRECTORY ?= $(HOME)/.local/bin

build:
	swift build --configuration release

install: build
	mkdir -p $(INSTALL_DIRECTORY)
	install -m 755 .build/release/monkeys $(INSTALL_DIRECTORY)/monkeys

clean:
	swift package clean

.PHONY: build install clean
