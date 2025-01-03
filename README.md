# ODIN JSON PARSER

JSON parser written in odin because ginger beard man told me to. Only reports errors, so
you can basically use it for validation.

## Build

If on linux just run `./build.sh`. Otherwise just run the following:

```bash
# mkdir build
$ odin build src -collection:src=src -out:build/json
$ ./build/json <file.json>
```

