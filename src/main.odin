package main

import "core:fmt"
import "core:os"

import "src:parser"
import "src:utils"

main :: proc() {
  if len(os.args) < 2 {
      fmt.eprintln("Expected a json file but got nothing!")
      fmt.eprintfln("Usage:\n\t%s <file.json>", os.args[0])
      os.exit(1)
  }
  
  source := utils.load(os.args[1])
  p := parser.parser(source)
  data := parser.run(p)
  fmt.println(data)
}

