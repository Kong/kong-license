install:
	mkdir -p ~/.local/bin
	ln -sf $$(pwd)/license.sh ~/.local/bin/license

lint:
	bash -c 'shopt -s globstar nullglob &> /dev/null; shellcheck *.{sh,ksh,bash}'
