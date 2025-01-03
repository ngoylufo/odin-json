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
  
  source := utils.read(os.args[1])
  p := parser.parser(source)
  _, err := parser.run(p)

  if err != nil do switch v in err {
  case parser.Unexpected_End_Of_Content:
     utils.exit("Malformed JSON: Unexpected end of content")
  case parser.Unexpected_Malformed_Value:
     utils.exit("Malformed JSON: %s", v.reason)
  case parser.Unexpected_Nothingness:
    utils.exit("Expected JSON content but got absolutely nothing")
  case parser.Unexpected_Character:
    utils.exit("Unexpected character: %c", v.char, loc=v.loc)
  case parser.Unexpected_Character_Mismatch:
    utils.exit("Expected %c but instead got %c", v.expected, v.received, loc=v.loc)
  case parser.Unexpected_Keyword:
    utils.exit("Expected a keyword (true, false, null) but instead got %s", v.word)
  }
}

