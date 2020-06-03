module module3 #(
    parameter integer WIDTH = 0
)(
    input wire clk_i,
    input wire rst_i,

    input wire enable_i,

    input wire [WIDTH-1:0] data_i,
    output wire [WIDTH-1:0] data_o
);

    reg my_reg = 1'b0;
    `include "src3.vh"

    reg [WIDTH_FROM_HEADER-1:0] wider_reg = 0;

    always @(posedge clk_i) begin
        my_reg <= `NOT(my_reg);
        wider_reg <= wider_reg + 1;
    end

    wire my_reg_from_module4;
    module4 module4_inst (
        .a (my_reg),
        .b (my_reg_from_module4)
    );

endmodule
