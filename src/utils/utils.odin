package utils

import "core:os"
import "core:fmt"
import "core:strings"

// Reads a file and returns its contents as bytes. Exits the program on error.
read :: proc(filepath: string) -> []byte {
	info, err := os.stat(filepath)
	if err != os.ERROR_NONE {
		exit(`Could not read file '%s': %s`, filepath, os.error_string(err))
	}

	if info.is_dir {
		exit(`"%s" is a directory.`, filepath)
	}

	if !strings.has_suffix(info.name, ".json") {
		exit(`Expected a \".json\" file, but got "%s"!`, info.name)
	}

  source, source_err := os.read_entire_file_from_filename_or_err(filepath)
	if source_err != nil do exit("Failed to read file %s: %s.", filepath, os.error_string(source_err))
	return source
}

// Prints an error message to STDERR and exits with code 1.
exit :: proc(message: string, args: ..any, loc := #caller_location) {
	fmt.eprintfln("\033[37;4;1m%s\033[0m \033[31;1mError:\033[0m %s", loc, fmt.tprintf(message, ..args))
	os.exit(1)
}

