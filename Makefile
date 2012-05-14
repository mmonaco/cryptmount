BIN      ?= cryptmount
MANPAGES := crypttab.5 cryptmount.8

PREFIX   ?= /usr/local
BINDIR   ?= $(PREFIX)/bin
LIBDIR   ?= $(PREFIX)/lib
DATADIR  ?= $(PREFIX)/share
MANDIR   ?= $(DATADIR)/man

DOCDIRS  := $(addprefix $(DESTDIR)$(MANDIR)/man, 5 8) $(DESTDIR)$(DATADIR)/$(BIN)
HOOKDIRS := $(addprefix $(DESTDIR)$(LIBDIR)/initcpio/, install hooks)


all: $(BIN) $(MANPAGES)


$(BIN): $(BIN).sh
	cp $< $@

man: $(MANPAGES)

%.5: %.5.txt
	a2x -d manpage -f manpage $<

%.8: %.8.txt
	a2x -d manpage -f manpage $<


install: install_bin install_doc

install_bin: $(BIN) $(DESTDIR)$(BINDIR)
	install -m755 -t $(DESTDIR)$(BINDIR) $(BIN)

install_doc: $(MANPAGES) crypttab.example $(DOCDIRS)
	install -m644 -t $(DESTDIR)$(MANDIR)/man5 $(filter %.5, $(MANPAGES))
	install -m644 -t $(DESTDIR)$(MANDIR)/man8 $(filter %.8, $(MANPAGES))
	install -m644 -t $(DESTDIR)$(DATADIR)/$(BIN) crypttab.example

install_hook: archlinux/encrypt_hook archlinux/encrypt_install $(HOOKDIRS)
	install -m644 archlinux/encrypt_install $(DESTDIR)$(LIBDIR)/initcpio/install/encrypt2
	install -m644 archlinux/encrypt_hook    $(DESTDIR)$(LIBDIR)/initcpio/hooks/encrypt2

$(DESTDIR)$(BINDIR) $(HOOKDIRS) $(DOCDIRS):
	install -m755 -d $@


clean:
	$(RM) $(BIN) $(MANPAGES)

.PHONY: all man clean install install_bin install_doc install_hook
