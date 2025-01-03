package parser

import "core:strconv"
import "base:runtime"

Parser :: struct {
  source: []byte,
  cursor: int,
}

parser :: proc(source: []byte) -> ^Parser {
  p := new(Parser)
  p.source = source

  return p
}

eof :: proc(p: ^Parser) -> bool {
  return p.cursor >= len(p.source)
}

peek :: proc(p: ^Parser) -> byte {
  return eof(p) ? 0 : p.source[p.cursor]
}

next :: proc(p: ^Parser) -> byte {
  idx := p.cursor
  p.cursor += 1
  return p.source[idx]
}

consume_whitespace :: proc(p: ^Parser) {
  for char := peek(p); !eof(p) && is_whitespace(char); char = peek(p) do next(p) 
}

consume :: proc(p:^Parser, char: byte, loc := #caller_location) -> Parsing_Error {
  if c := next(p); c != char {
    return Unexpected_Character_Mismatch{ expected = char, received = c, loc = loc }
  }
  return nil
}

parse_string :: proc(p: ^Parser, node: ^Node) -> Parsing_Error {
  start, end := p.cursor, p.cursor
  for end <= len(p.source) && p.source[end] != '"' {
    // Todo: Espace sequences need checking.
    end += 1
  }
  p.cursor = end
  consume(p, '"') or_return

  str := String{ data = p.source[start:end] }
  node.data = str
  
  return nil
}

parse_number :: proc(p: ^Parser, node: ^Node) -> Parsing_Error {
  start := p.cursor - 1
  p.cursor = start
  
  for char := peek(p); !eof(p) && is_valid_number_character(char); char = peek(p) {
    p.cursor += 1
  }

  str := cast(string)p.source[start:p.cursor ]
  node.data = Number{ value = strconv.atof(str) }

  return nil
}

parse_keyword :: proc(p: ^Parser, node: ^Node) -> Parsing_Error {
  start := p.cursor - 1
  for char := peek(p); !(eof(p) || is_whitespace(char)) && is_character(char); char = peek(p) {
      p.cursor += 1
  }

  keyword := cast(string)p.source[start:p.cursor]
  
  if keyword == "true" {
    node.data = Boolean{true}
    return nil
  }

   if keyword == "false" {
    node.data = Boolean{false}
    return nil
  }

  if keyword == "null" {
    node.data = Null{}
    return nil
  }
 
  return Unexpected_Keyword{ word = keyword }
}

parse_array :: proc(p: ^Parser, node: ^Node) -> Parsing_Error {
  // node.data = Array{}
  values := make([dynamic]JSON, 0, 8)
  
  for char := peek(p); !(eof(p) || char == ']'); char = peek(p) {
    n: Node = Node { prev = node }
    
    parse(p, &n) or_return
    consume_whitespace(p)
      
    if peek(p) == ',' {
      consume(p, ',')
      consume_whitespace(p)

      if peek(p) == ']' {
        return Unexpected_Malformed_Value{"Trailing comma in array"}
      }
    }
    
    if n.data == nil || eof(p) {
      return Unexpected_End_Of_Content{}
    }
    append(&values, n.data)
  }
  consume(p, ']') or_return

  node.data = Array{ data = values[:] }
  return nil
}

parse_object :: proc(p: ^Parser, node: ^Node) -> Parsing_Error {
  obj := make(map[string]JSON)

  for char := peek(p); !(eof(p) || char == '}'); char = peek(p) {
    key, value: Node = { prev = node }, { prev = node }

    consume_whitespace(p)
    consume(p, '"') or_return
    parse_string(p, &key) or_return
   
    consume_whitespace(p)
    consume(p, ':') or_return

    parse(p, &value) or_return
    consume_whitespace(p)

    if peek(p) == ',' {
      consume(p, ',') or_return
      consume_whitespace(p)
    
      if peek(p) == '}' {
        return Unexpected_Malformed_Value{"Trailing comma in object literal"}
      }
    }

    if value.data == nil || eof(p) {
      return Unexpected_End_Of_Content{}
    }

    k := key.data.(String)
    obj[cast(string)k.data] = value.data 
  }
  consume(p, '}') or_return
  
  node.data = Object{ data = obj }
  return nil
}

is_whitespace :: proc(c: byte) -> bool {
  return c >= 1 && c <= 32
}

is_character :: proc(c: byte) -> bool {
  return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) 
}

is_start_of_number := proc(c: byte) -> bool {
  return c == '-' || c >= 48 && c <= 57
} 

is_valid_number_character := proc(c: byte) -> bool {
  return is_start_of_number(c) || c == '+' || c == 'e' || c == 'E' || c == '.'
}

Node :: struct { prev: ^Node, data: JSON }

parse :: proc(p: ^Parser, node: ^Node, loc := #caller_location) -> Parsing_Error {
  consume_whitespace(p)
  
  if !eof(p) do switch char := next(p); true {
  case char == '"':
    parse_string(p, node) or_return
  case is_start_of_number(char):
    parse_number(p, node) or_return
  case char == 't', char == 'f', char == 'n':
    parse_keyword(p, node) or_return
  case char == '[':
    parse_array(p, node) or_return
  case char == '{':
    parse_object(p, node) or_return
  case:
    return Unexpected_Character{ loc, char }
  }

  return nil
}

run :: proc(p: ^Parser) -> (data: JSON, err: Parsing_Error) {
  node: Node
  parse(p, &node) or_return
  if node.data == nil {
    return nil, Unexpected_Nothingness{}
  }
  return node.data, nil
}

// print_error :: proc(err: Parsing_Error) {

// }

JSON :: union {
  String,
  Number,
  Object,
  Array,
  Boolean,
  Null,
}

String :: struct {
  data: []byte, // Todo: Convert to odin string. Maybe use Raw_String?
}

Number :: struct {
  value: f64,
}

Object :: struct {
  data: map[string]JSON,
}

Array :: struct {
  data: []JSON,
}

Boolean :: struct {
  value: bool,
}

Null :: struct {}

Unexpected_Nothingness :: struct {}

Unexpected_End_Of_Content :: struct {}

Unexpected_Malformed_Value :: struct {
  reason: string,
}

Unexpected_Character :: struct {
  loc: runtime.Source_Code_Location,
  char: byte,
}

Unexpected_Character_Mismatch :: struct {
  loc: runtime.Source_Code_Location,
  expected, received: byte,
}

Unexpected_Keyword :: struct {
  word: string,
}

Parsing_Error :: union {
  Unexpected_Nothingness,
  Unexpected_End_Of_Content,
  Unexpected_Character,
  Unexpected_Character_Mismatch,
  Unexpected_Keyword,
  Unexpected_Malformed_Value,
}

