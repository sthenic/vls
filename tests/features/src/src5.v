(* some_attr = "true" *) module module5 #(
    parameter FOO = 0, parameter BaR = "baz"
)(
    .clk_i(clk_local),
    data_o, valid_o
);
    input wire clk_local;
    output wire data_o;
    output wire valid_o;

    reg tmp = 1'b0;
    always @(posedge clk_local)
        tmp <= ~tmp;
    assign data_o = tmp;

    module4 module4_inst (
        (* some_attr = "true" *) .clk_i (clk_local),
        .data_o (from_module4)
    );

    localparam ANOTHER_FOO = FOO;

endmodule
