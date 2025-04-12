package main

import "core:fmt"
import "core:os"

import "src:parser"
import "src:utils"

main :: proc() {
    if len(os.args) < 2 {
        utils.exit("Expected a json file but got nothing!\nUsage:\n\t%s <file.json>", os.args[0])
    }
    data := parse(source = utils.load(os.args[1]))
    fmt.println(data)
}

parse :: proc(source: ^utils.Source) -> parser.JSON {
    p := parser.parser(source)
    return parser.run(p)
}

