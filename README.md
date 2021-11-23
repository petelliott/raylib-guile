# raylib-guile

raylib-guile is *birthdayware* written for my good friend
[Jacob Reckhard](https://github.com/jacobrec)'s birthday 🥳.
it provides direct GNU guile bindings for [raylib](https://github.com/raysan5/raylib).
if you're not Jacob, don't worry: you can still use it under the terms of the
[zlib license](/LICENSE), the same one used by raylib.

## builing and installing

prerequisites:
 - guile 3.0 or later
 - raylib built with shared library support

```sh
make
sudo make install
```

note: `make` will download the master-brach version of raylib's api
description. if this causes errors you should download the `raylib_api.xml` that
corresponds to the version of raylib you have installed.

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