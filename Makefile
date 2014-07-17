
INSTALLDIR := installdir

all:    dummy

build_depends:
	aptitude install libtest-file-contents-perl

install:
	mkdir -p $(INSTALLDIR)
	echo copy stuff

re.pl:
	PERL5OPT=-I./lib re.pl

cover:
	cover -delete
	COVER=true $(MAKE) test
	cover

test:
	~/s/bin/lib/test_harness

