module demo_module();

    wire clk_i;
    wire [7:0] to_pipeline;
    wire [7:0] from_pipeline;

    pipeline #(
        .WIDTH(8),
        .NOF_STAGES(3),
        .A_NEW_PARAMETER("HI")
    ) pipeline_inst (
        .clk_i(clk_i),
        .data_i(to_pipeline),
        .data_o(from_pipeline)
    );

endmodule
