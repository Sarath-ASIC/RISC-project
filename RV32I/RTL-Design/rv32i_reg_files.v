`timescale 1ns/1ps

module rv32i_regfile (
    input         clk,
    input         reset,

    input  [4:0]  rs1,
    input  [4:0]  rs2,

    output [31:0] rs1_data,
    output [31:0] rs2_data,

    input         reg_write,
    input  [4:0]  rd,
    input  [31:0] rd_data
);

    reg [31:0] regs [0:31];

    integer i;

    // ------------------------------------------------------------
    // Read ports
    // ------------------------------------------------------------

    assign rs1_data = (rs1 == 5'd0) ? 32'd0 : regs[rs1];

    assign rs2_data = (rs2 == 5'd0) ? 32'd0 : regs[rs2];


    // ------------------------------------------------------------
    // Write port
    // ------------------------------------------------------------

    always @(posedge clk) begin

        if (reset) begin

            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;

        end

        else begin

            // x0 can never be changed

            regs[0] <= 32'd0;

            if (reg_write && (rd != 5'd0))
                regs[rd] <= rd_data;

        end

    end

endmodule
