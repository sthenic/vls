(* some_attr = "true" *) module module5 #(
    /* Docstring for `FOO`. */ parameter FOO = 0, parameter BaR = "baz"
)(
    .clk_i(clk_local), .split_port_i({first_half, second_half}),
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
    parameter LATE_DECLARATION = 32;

    input wire [LATE_DECLARATION/2-1: 0] first_half;
    input wire [LATE_DECLARATION/2-1: 0] second_half;

    module7 module7_inst (
        .clk_i (),
        .data_i ()
    );

    initial begin : thing
        fork : foo
            tmp = 1'b0 + $rtoi(3.14);
        join
        $display(FOOBAR, "Show this to the user!");
    end

    genvar k;
    for (k = 0; k < 8; k = k + 1) begin : loop
        localparam BAZ = 1'b0;
    end

    module7 module7_inst (
    );

    /* FIXME: Rename operation in the port list renames this symbol too: */
    /* wire split_port_i; */

endmodule
