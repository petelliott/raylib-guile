# raylib-guile

raylib-guile is *birthdayware* written for my good friend
[Jacob Reckhard](https://github.com/jacobrec)'s birthday 🥳.
it provides direct GNU guile bindings for [raylib](https://github.com/raysan5/raylib).
if you're not Jacob, don't worry: you can still use it under the terms of the
[zlib license](/LICENSE), the same one used by raylib.

## building and installing

prerequisites:
 - guile 3.0 or later
 - raylib built with shared library support

```sh
make
sudo make install
```

note: `make` will download the master-brach version of raylib's api
description. if this causes errors you should change the `VERSION` file to the
version of raylib you have installed. right now all tagged versions xml files
are out of date, and you might need to generate them yourself.

## generated API

all supported functions are exported as is in the `(raylib)` library and take
equivalant arguments. pointer/value arguments are equivalent for structs.

the following accessors are generated for every struct type:
```
(make-{struct} field1 field2 ...)
({struct}-field obj)
({struct}-set-field! obj value)
```

## examples

you can see some examples in the `examples/` directory. they are directly
translated from raylib's examples, and as such may not represent very elegant
scheme programming.

## to Jacob, my best programming buddy

happy birthday! one day at a party you were complaining about how there were
raylib bindings for like every language except guile, and you joked that if i
was looking for something to do, i should write some. so i did. along with the
rights granted to you by zlib license, i hearby grant you a special birthday boy
license, with the following terms:

0. if you want, i will add you as a contributor to this repo, and you may have
   complete creative control over this project.
1. you may relicense this program under any license, even weird ones you made up.
2. one year of platinum-executive-enterprise support.