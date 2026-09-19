INSTALL_DIRECTORY ?= $(HOME)/.local/bin

build:
	swift build --configuration release

install: build
	mkdir -p $(INSTALL_DIRECTORY)
	install -m 755 .build/release/keyenv $(INSTALL_DIRECTORY)/keyenv

clean:
	swift package clean

.PHONY: build install clean
