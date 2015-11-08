PACKAGE = openssh
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=$(RELEASE_DIR) --sbindir=$(RELEASE_DIR)/usr/bin --bindir=$(RELEASE_DIR)/usr/bin --mandir=$(RELEASE_DIR)/usr/share/man --libdir=$(RELEASE_DIR)/usr/lib --includedir=$(RELEASE_DIR)/usr/include --docdir=$(RELEASE_DIR)/usr/share/doc/$(PACKAGE) --sysconfdir=/etc/ssh --libexecdir=/usr/lib/ssh --with-pid-dir=/run
CONF_FLAGS = --with-privsep-user=nobody --with-ldflags=-static

PACKAGE_VERSION = $$(awk '/^Version/ {print $$2}' upstream/contrib/suse/openssh.spec)
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

ZLIB_VERSION = 1.2.8-1
ZLIB_URL = https://github.com/amylum/zlib/releases/download/$(ZLIB_VERSION)/zlib.tar.gz
ZLIB_TAR = zlib.tar.gz
ZLIB_DIR = /tmp/zlib
ZLIB_PATH = -I$(ZLIB_DIR)/usr/include -L$(ZLIB_DIR)/usr/lib

SSL_VERSION = 1.0.2d-1
SSL_URL = https://github.com/amylum/openssl/releases/download/$(SSL_VERSION)/openssl.tar.gz
SSL_TAR = /tmp/ssl.tar.gz
SSL_DIR = /tmp/ssl
SSL_PATH = --with-ssl-dir=$(SSL_TARGET)/tmp/ssl

.PHONY : default submodule deps manual container build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(SSL_DIR) $(SSL_TAR)
	mkdir $(SSL_DIR)
	curl -sLo $(SSL_TAR) $(SSL_URL)
	tar -x -C $(SSL_DIR) -f $(SSL_TAR)
	rm -rf $(ZLIB_DIR) $(ZLIB_TAR)
	mkdir $(ZLIB_DIR)
	curl -sLo $(ZLIB_TAR) $(ZLIB_URL)
	tar -x -C $(ZLIB_DIR) -f $(ZLIB_TAR)

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && autoheader && autoconf
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS="$(CFLAGS)" ./configure $(PATH_FLAGS) $(CONF_FLAGS) $(ZLIB_PATH) $(SSL_PATH)
	cd $(BUILD_DIR) && make install
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/LICENCE $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

