
all: libraylib-guile.so raylib.scm

libraylib-guile.so: raylib-guile.c
	gcc `pkg-config --cflags guile-3.0` -shared -o $@ -fPIC $^ -lraylib

raylib.scm raylib-guile.c: raylib_api.xml generate-bindings.scm
	./generate-bindings.scm $<

raylib_api.xml:
	wget 'https://raw.githubusercontent.com/raysan5/raylib/master/parser/raylib_api.xml'

clean:
	rm raylib-guile.c libraylib-guile.so raylib.scm -f

.PHONY: clean all
