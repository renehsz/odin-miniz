# odin-miniz
[![license](https://img.shields.io/github/license/ReneHSZ/odin-miniz.svg)](https://github.com/ReneHSZ/odin-miniz/blob/master/LICENSE)
[![contributors](https://img.shields.io/github/contributors/ReneHSZ/odin-miniz.svg)](https://github.com/ReneHSZ/odin-miniz/graphs/contributors)
[![issues](https://img.shields.io/github/issues/ReneHSZ/odin-miniz.svg)](https://github.com/ReneHSZ/odin-miniz/issues)

A binding to the [miniz compression library](https://github.com/richgel999/miniz) for the [Odin programming language](http://odin-lang.org).

## Installation
You need `curl`, a C compiler (default: `gcc`) and an archiver (default: `ar`) in order to compile the miniz library itself.

Then just clone this repository into your `shared` collection and run `build-miniz.sh`.
This will create an archive file, which will be linked in when using miniz.odin.

Then use it with
```
import miniz "shared:odin-miniz";
```

See `demo/main.odin` for an example on how to use this library. If you need more information, take a look at the source code (it's fairly easy to understand).

## License
It is *public domain* ([UNLICENSE](http://unlicense.org)), see [LICENSE](LICENSE) file for further details.

