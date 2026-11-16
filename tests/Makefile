# PC tests: make test (host-antiword.sh fetches Antiword at antiword.lock's commit)
CC ?= cc
test:
	sh test-part.sh
	mkdir -p ../build-host
	$(CC) -Wall -Wextra -I../amiga -o ../build-host/path_test path_test.c ../amiga/aw_path.c && ../build-host/path_test
	sh host-antiword.sh
.PHONY: test
