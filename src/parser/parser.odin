package parser

import "core:strconv"
import "base:runtime"

import "src:utils"

Parser :: struct {
  source: ^utils.Source,
  cursor: int,
}

parser :: proc(source: ^utils.Source, allocator := context.allocator) -> ^Parser {
  p := new(Parser, allocator)
  p^ = Parser{ source, 0 }
  return p
}

eof :: proc(p: ^Parser) -> bool {
  return p.cursor >= len(p.source.data)
}

peek :: proc(p: ^Parser) -> byte {
  return eof(p) ? 0 : p.source.data[p.cursor]
}

next :: proc(p: ^Parser) -> byte {
  p.cursor += 1
  return p.source.data[p.cursor - 1]
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
  start := p.cursor
  for char := peek(p); !(eof(p) || char == '"'); char = peek(p) {
    if char >= 0 && char <= 31 do return Unexpected_Control_Character{ char }
    if char == '\\' do switch peek(p) {
    case 't', 'r', 'n', 'f', 'b', '/', '\\', '"':
      consume(p, peek(p))
    case 'u':
      consume(p, 'u')
      for i := 0; i < 4; i += 1 {
        if !is_hex_digit(p.source.data[p.cursor + i]) {
          sequence := cast(string)p.source.data[p.cursor:p.cursor+4]
          return Invalid_Escape_Sequence{ sequence = sequence }
        }
      }
      p.cursor += 4
    }
    next(p)
  }
  
  // start, end := p.cursor, p.cursor
  // for end <= len(p.source) && p.source.data[end] != '"' {
  //   if char := p.source.data[end]; char == '\\' {
  //     switch peek(t) {
  //     case:
        
  //     }
  //   }
  
  //   // Todo: Espace sequences need checking.
  //   end += 1
  // }
  // p.cursor = end
  consume(p, '"') or_return

  str := String{ data = p.source.data[start:p.cursor] }
  node.data = str

  return nil
}

parse_number :: proc(p: ^Parser, node: ^Node) -> Parsing_Error {
  start := p.cursor - 1
  p.cursor = start
  
  for char := peek(p); !eof(p) && is_valid_number_character(char); char = peek(p) {
    p.cursor += 1
  }

  str := cast(string)p.source.data[start:p.cursor]
  node.data = Number{ value = strconv.atof(str) }

  return nil
}

parse_keyword :: proc(p: ^Parser, node: ^Node) -> Parsing_Error {
  start := p.cursor - 1
  for char := peek(p); !(eof(p) || is_whitespace(char)) && is_character(char); char = peek(p) {
      p.cursor += 1
  }

  keyword := cast(string)p.source.data[start:p.cursor]
  
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

parse_array :: proc(p: ^Parser, node: ^Node, allocator := context.allocator) -> Parsing_Error {
  // node.data = Array{}
  values := make([dynamic]JSON, 0, 8, allocator)
  
  for char := peek(p); !(eof(p) || char == ']'); char = peek(p) {
    n: Node = Node { prev = node }
    
    parse(p, &n, allocator) or_return
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

parse_object :: proc(p: ^Parser, node: ^Node, allocator := context.allocator) -> Parsing_Error {
  obj := make(map[string]JSON, allocator)

  for char := peek(p); !(eof(p) || char == '}'); char = peek(p) {
    key, value: Node = { prev = node }, { prev = node }

    consume_whitespace(p)
    consume(p, '"') or_return
    parse_string(p, &key) or_return
   
    consume_whitespace(p)
    consume(p, ':') or_return

    parse(p, &value, allocator) or_return
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
  return c == '-' || is_digit(c)
} 

is_valid_number_character := proc(c: byte) -> bool {
  return is_start_of_number(c) || c == '+' || c == 'e' || c == 'E' || c == '.'
}

is_digit :: proc(c: byte) -> bool {
  return c >= 48 && c <= 57
}

is_hex_digit :: proc(c: byte) -> bool {
  return is_digit(c) || c >= 65 && c <= 70 || c >= 97 && c <= 102
}

Node :: struct { prev: ^Node, data: JSON }

parse :: proc(p: ^Parser, node: ^Node, allocator := context.allocator, loc := #caller_location) -> Parsing_Error {
  consume_whitespace(p)
  
  if !eof(p) do switch char := next(p); true {
  case char == '"':
    parse_string(p, node) or_return
  case is_start_of_number(char):
    parse_number(p, node) or_return
  case char == 't', char == 'f', char == 'n':
    parse_keyword(p, node) or_return
  case char == '[':
    parse_array(p, node, allocator) or_return
  case char == '{':
    parse_object(p, node, allocator) or_return
  case:
    return Unexpected_Character{ loc, char }
  }

  return nil
}

run :: proc(p: ^Parser, allocator := context.allocator) -> JSON {
    node: Node

    if err := parse(p, &node, allocator); err != nil {
        switch v in err {
        case Unexpected_End_Of_Content:
            utils.exit("Malformed JSON: Unexpected end of content")
        case Unexpected_Malformed_Value:
            utils.exit("Malformed JSON: %s", v.reason)
        case Unexpected_Nothingness:
            utils.exit("Expected JSON content but got absolutely nothing")
        case Unexpected_Character:
            utils.exit("Unexpected character: %c", v.char, loc=v.loc)
        case Unexpected_Character_Mismatch:
            utils.exit("Expected %c but instead got %c", v.expected, v.received, loc=v.loc)
        case Unexpected_Keyword:
            utils.exit("Expected a keyword (true, false, null) but instead got %s", v.word)
        case Invalid_Escape_Sequence:
            utils.exit("Invalid_Escape_Sequence: %s", v.sequence)
        case Unexpected_Control_Character:
            utils.exit("Unexpected control character: %c", v.char)
        }
    }

    if node.data == nil {
        utils.exit("Expected JSON content but got absolutely nothing")
    }

    return node.data
}


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

Invalid_Escape_Sequence :: struct {
  sequence: string,
}

Unexpected_Control_Character :: struct {
  char: byte,
}

Parsing_Error :: union {
  Unexpected_Nothingness,
  Unexpected_End_Of_Content,
  Unexpected_Character,
  Unexpected_Character_Mismatch,
  Unexpected_Keyword,
  Unexpected_Malformed_Value,
  Invalid_Escape_Sequence,
  Unexpected_Control_Character,
}

