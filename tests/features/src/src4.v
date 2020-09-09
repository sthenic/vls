(* some_attr = "true" *) module module4 (/* The clock input. */
    (* another_attr = "false" *) input wire clk_i,
    /* The 1-bit data output port. */
    output wire data_o
);

    reg tmp = 1'b0;
    always @(posedge clk_i)
        tmp <= ~tmp;
    assign data_o = tmp;

    localparam BAR = 10, FOO = 23;
    wire [1:0] out;
    module5 #(
        .FOO (BAR), .BaR (FOO), .LATE_DECLARATION (6)
    ) module5_inst [1:0] (
        .clk_i (clk_i),
        .data_o (out[0]),
        .valid_o (out[1]),
        .split_port_i (6'b100101)
    );

    parameter MODULE4_PARAMETER = 32;

endmodule
