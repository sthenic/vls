WID=`xdotool search --name 'Visual Studio Code'`
echo "Window id is" $WID
XTEXT="xvkbd -delay 80 -window $WID -text "
XKEY="xdotool key --delay 80 "
CLEARMOUSE="xdotool mousemove --window $WID 1200 185"
SLEEP="sleep 1"
SLEEPLONG="sleep 2"

$CLEARMOUSE
$XTEXT "module demo_module();\r\r"
sleep 0.5
$XTEXT "endmodule\C\S\r\C\S\r"
$XTEXT "\tpipe"
$SLEEPLONG
$XTEXT "\r"
$SLEEP

# Demonstrate hover.
xdotool mousemove --window $WID 200 185
$SLEEPLONG

# Goto declaration.
xdotool click 1
$CLEARMOUSE
$SLEEP
$XTEXT "\C\SPgoto decl"
$SLEEP
$XTEXT "\r"
# $XTEXT "\[F12]"

# Peek references.
$SLEEP
$XTEXT "\C\SPpeek"
$SLEEP
$XTEXT "\r"
$SLEEP
$XTEXT "\[Down]"
$SLEEP
$XTEXT "\[Up]"
$SLEEP
$XTEXT "\[Escape]"

# Add a new port.
$XTEXT "\C\r"
$SLEEP
$XTEXT "input wire rst_i,\C\S\r"
$XTEXT "/* The synchronous reset. */\Cs"
$SLEEP

# Show the missing port error.
$XTEXT "\A1"
$SLEEP
$XTEXT "\Cs"
$SLEEP
xdotool mousemove --window $WID 180 170
$SLEEPLONG
$CLEARMOUSE
$XTEXT "\[End]"
$SLEEP
$XTEXT "\r.r"
$SLEEP
$XTEXT "\C "
$SLEEP
$XTEXT "\r,\Cs"
$SLEEP
