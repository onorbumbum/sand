PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
CONFIG ?= release
SWIFT ?= swift
INSTALL ?= install
RM ?= rm -f

.PHONY: build test docs-check check install uninstall

build:
	$(SWIFT) build -c $(CONFIG)

test:
	$(SWIFT) test

docs-check:
	scripts/docs-check.sh

check:
	$(SWIFT) test
	scripts/docs-check.sh

install: build
	$(INSTALL) -d "$(DESTDIR)$(BINDIR)"
	$(INSTALL) -m 0755 ".build/$(CONFIG)/sand" "$(DESTDIR)$(BINDIR)/sand"

uninstall:
	$(RM) "$(DESTDIR)$(BINDIR)/sand"
