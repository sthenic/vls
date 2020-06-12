(* some_attr = "true" *) module module4 (
    (* another_attr = "false" *) input wire clk_i,
    output wire data_o
);

    reg tmp = 1'b0;
    always @(posedge clk_i)
        tmp <= ~tmp;
    assign data_o = tmp;

    wire [1:0] out;
    module5 module5_inst (
        .clk_i (clk_i),
        .data_o (out[0]),
        .valid_o (out[1])
    );

endmodule
