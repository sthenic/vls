import streams
import ./server

var s: LspServer
open(s, new_file_stream(stdin), new_file_stream(stdout))
let exit_code = run(s)
close(s)
quit(exit_code)
