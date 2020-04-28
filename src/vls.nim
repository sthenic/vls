import json
import streams
import strutils

var ifs = new_file_stream(stdin)
var ofs = new_file_stream(stdout)

when is_main_module:
   while true:
      var header = ""
      if not read_line(ifs, header):
         echo "Input stream closed."
         break

      if len(header) == 0:
         echo "empty!"
         continue

      if not starts_with(header, "Content-Length: "):
         echo "error!"
         continue

      let length =
         try:
            parse_int(substr(header, 16))
         except ValueError:
            -1

      if length < 0:
         echo "error invalid length ", length
         continue

      let frame = read_str(ifs, length)
      let node =
         try:
            parse_json(frame)
         except JsonParsingError:
            echo "failed JSON parsing"
            continue

      write_line(ofs, pretty(node))

