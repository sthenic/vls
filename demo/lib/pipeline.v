/* A parametrized pipeline module. You're able to configure the *width*
   (`WIDTH`) and the *number of stages* (`NOF_STAGES`)  */
module pipeline #(
    /* The width of the data ports. */
    parameter integer WIDTH = 0,
    /* The number of pipeline stages. */
    parameter integer NOF_STAGES = 0,
    parameter A_NEW_PARAMETER = "HELLO"
)(
    /* The clock signal. */
    input wire clk_i,
    /* The pipeline's data input, this signal is `WIDTH` bits wide. */
    input wire [WIDTH-1:0] data_i,
    /* The pipeline's data output, this signal is `WIDTH` bits wide. */
    output wire [WIDTH-1:0] data_o
);

    reg [NOF_STAGES*WIDTH-1:0] shift_registers = {(NOF_STAGES*WIDTH){1'b0}};

    always @(posedge clk_i) begin
        shift_registers[NOF_STAGES*WIDTH-1:WIDTH] <= shift_registers[NOF_STAGES*(WIDTH-1)-1:0];
        shift_registers[0 +: WIDTH] <= data_i;
    end

    assign data_o = shift_registers[NOF_STAGES-1];

endmodule
