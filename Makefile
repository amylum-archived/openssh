PACKAGE = openssh
ORG = amylum

DEP_DIR = /tmp/dep-dir

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=$(RELEASE_DIR) --sbindir=$(RELEASE_DIR)/usr/bin --bindir=$(RELEASE_DIR)/usr/bin --mandir=$(RELEASE_DIR)/usr/share/man --libdir=$(RELEASE_DIR)/usr/lib --includedir=$(RELEASE_DIR)/usr/include --docdir=$(RELEASE_DIR)/usr/share/doc/$(PACKAGE) --sysconfdir=/etc/ssh --libexecdir=/usr/lib/ssh --with-pid-dir=/run
CONF_FLAGS = --with-privsep-user=nobody --with-zlib=/usr/include --with-cflags='-static'

PACKAGE_VERSION = $$(awk '/^Version/ {print $2}' upstream/contrib/suse/openssh.spec)
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

.PHONY : default submodule manual container build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

build: submodule
	rm -rf $(BUILD_DIR) $(DEP_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && autoconf
	cd $(BUILD_DIR) && CC=musl-gcc ./configure $(PATH_FLAGS) $(CONF_FLAGS)
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
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)

local: build push

