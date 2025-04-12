package utils

import "core:os"
import "core:fmt"
import "core:strings"

// Reads a file and returns its contents as bytes. Exits the program on error.
Source :: struct {
	pathname: string,
	data:     []byte,
}

load :: proc(pathname: string, allocator := context.allocator) -> ^Source {
    info, info_err := os.stat(pathname)

    if info_err != os.ERROR_NONE do exit(`Could not read file '%s': %s`, pathname, os.error_string(info_err))
    if info.is_dir do exit(`"%s" is a directory.`, pathname)
    if !strings.has_suffix(info.name, ".json") do exit(`Expected a \".json\" file, but got "%s"!`, info.name)

    data, data_err := os.read_entire_file_from_filename_or_err(info.fullpath, allocator)
    if data_err != nil do exit("Failed to read file %s: %s.", info.name, os.error_string(data_err))

    source := new(Source, allocator)
    source^ = Source{ info.fullpath, data }

    return source
}

// Prints an error message to STDERR and exits with code 1.
exit :: proc(message: string, args: ..any, loc := #caller_location) {
	fmt.eprintfln("\033[37;4;1m%s\033[0m \033[31;1mError:\033[0m %s", loc, fmt.tprintf(message, ..args))
	os.exit(1)
}

