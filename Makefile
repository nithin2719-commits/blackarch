# Packaging entry point.
#
# install.sh is the *user* installer: it symlinks into ~/.local/bin, wires a
# keybinding into the user's compositor config, and builds an index. A distro
# package must do none of those -- it may only place files under $(DESTDIR),
# and it must never touch $HOME or a running desktop. So packaging uses this
# instead, and the keybinding stays the user's own opt-in step afterwards.
#
#   make DESTDIR=/tmp/pkg PREFIX=/usr install
#
PREFIX  ?= /usr/local
DESTDIR ?=

SHAREDIR = $(DESTDIR)$(PREFIX)/share/blackarch-toolbox
BINDIR   = $(DESTDIR)$(PREFIX)/bin
DOCDIR   = $(DESTDIR)$(PREFIX)/share/doc/blackarch-toolbox
LICDIR   = $(DESTDIR)$(PREFIX)/share/licenses/blackarch-toolbox
APPDIR   = $(DESTDIR)$(PREFIX)/share/applications

.PHONY: install uninstall check

install:
	install -d $(SHAREDIR)/bin $(SHAREDIR)/lib/backends $(SHAREDIR)/data \
	           $(SHAREDIR)/assets $(SHAREDIR)/config/rofi $(SHAREDIR)/config/kitty \
	           $(BINDIR) $(DOCDIR) $(LICDIR) $(APPDIR)
	install -m755 bin/blackarch-toolbox   $(SHAREDIR)/bin/
	install -m644 lib/*.sh lib/*.awk      $(SHAREDIR)/lib/
	install -m644 lib/backends/*.sh       $(SHAREDIR)/lib/backends/
	install -m644 data/*                  $(SHAREDIR)/data/
	install -m644 assets/*.png            $(SHAREDIR)/assets/
	install -m644 config/rofi/*.rasi      $(SHAREDIR)/config/rofi/
	install -m644 config/kitty/*.conf     $(SHAREDIR)/config/kitty/
	install -m644 config/config.example   $(SHAREDIR)/config/
	# /usr/bin entry point is a symlink; the script resolves its own root
	# through symlinks, so lib/ and data/ are still found from $(SHAREDIR).
	ln -sf $(PREFIX)/share/blackarch-toolbox/bin/blackarch-toolbox \
	       $(BINDIR)/blackarch-toolbox
	install -m644 README.md CHANGELOG.md  $(DOCDIR)/
	install -m644 LICENSE                 $(LICDIR)/
	install -m644 blackarch-toolbox.desktop $(APPDIR)/

uninstall:
	rm -rf $(SHAREDIR) $(DOCDIR) $(LICDIR)
	rm -f  $(BINDIR)/blackarch-toolbox $(APPDIR)/blackarch-toolbox.desktop

check:
	bash tests/smoke.sh
