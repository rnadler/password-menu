.POSIX:
EMACS   = emacs
BATCH   = $(EMACS) -batch -Q -L . -L test

EL   = password-menu.el
TEST = test/password-menu-tests.el

compile: $(EL:.el=.elc) $(TEST:.el=.elc)

check: test
test: $(EL:.el=.elc) $(TEST:.el=.elc)
	$(BATCH)  $(LDFLAGS) -l $(TEST) -f ert-run-tests-batch

clean:
	rm -f $(EL:.el=.elc) $(TEST:.el=.elc)

password-menu-tests.elc: password-menu.elc

.SUFFIXES: .el .elc

.el.elc:
	$(BATCH) -f batch-byte-compile $<
