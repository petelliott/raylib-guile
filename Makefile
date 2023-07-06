
all: libraylib-guile.so raylib.scm

install: all
	install libraylib-guile.so `pkg-config --variable=extensiondir guile-3.0`
	install raylib.scm `pkg-config --variable=sitedir guile-3.0`

libraylib-guile.so: raylib-guile.c
	gcc `pkg-config --cflags guile-3.0` -shared -o $@ -fPIC $^ -lraylib

raylib.scm raylib-guile.c: raylib_api.xml generate-bindings.scm
	./generate-bindings.scm $<

raylib_api.xml:
	wget "https://raw.githubusercontent.com/raysan5/raylib/`cat VERSION`/parser/output/raylib_api.xml"

clean:
	rm raylib-guile.c libraylib-guile.so raylib.scm -f

.PHONY: clean all install
