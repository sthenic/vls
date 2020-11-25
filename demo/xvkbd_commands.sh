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

# Add a named port connection for rst_i.
$XTEXT "\[End]"
$SLEEP
$XTEXT "\r.r"
$SLEEP
$XTEXT "\C "
$SLEEP
$XTEXT "\r,\Cs"
$SLEEP

# Connect local wires.
$XTEXT "\[Up]\[Up]\[Up]\[Up]\[Left]\[Left]"
$SLEEP
$XTEXT "8"
sleep 0.5
$XTEXT "\[Down]\[End]\[Left]"
sleep 0.5
$XTEXT "3"
$SLEEP
$XTEXT "\[Down]\[Down]\[Left]\[Left]"
sleep 0.5
$XTEXT "clk"
$XTEXT "\[Down]\[Left]\[Left]"
sleep 0.5
$XTEXT "rst"
$XTEXT "\[Down]\[Left]\[Left]"
sleep 0.5
$XTEXT "to_pipeline"
$XTEXT "\[Down]\[Left]"
sleep 0.5
$XTEXT "from_pipeline"
$XTEXT "\[Down]"

# Show 'undeclared identifier' message.
xdotool mousemove --window $WID 270 245
$SLEEPLONG
xdotool mousemove --window $WID 200 90
xdotool click 1
$CLEARMOUSE

# Add wire declarations.
$XTEXT "\C\S\r\C\r\t"
$XTEXT "wire clk;\r"
$SLEEP
$XTEXT "wire rst;\r"
$SLEEP
$XTEXT "wire [7:0] to_pipeline;\r"
$SLEEP
$XTEXT "wire [7:0] from_pipeline;\Cs"
$SLEEP

# Rename parameter.
$XTEXT "\[Down]\[Down]\[Down]\[Home]\[Right]\[Right]"
$SLEEP
$XTEXT "\[F12]"
$SLEEP
$XTEXT "\C\SPrename"
$SLEEPLONG
$XTEXT "\r"
$SLEEP
$XTEXT "NEW_WIDTH"
$SLEEP
$XTEXT "\r"
sleep 0.5
$XTEXT "\Cs"
sleep 0.5
$XTEXT "\A1"
sleep 0.5
$XTEXT "\Cs"
