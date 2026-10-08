`timescale 1ns/1ps

module tb_rv32i;


    // ============================================================
    // CLOCK / RESET
    // ============================================================

    reg clk;
    reg reset;


    // ============================================================
    // INSTRUCTION INTERFACE
    // ============================================================

    wire [31:0] imem_addr;

    reg [31:0] imem_rdata;


    // ============================================================
    // DATA INTERFACE
    // ============================================================

    wire        dmem_valid;
    wire        dmem_write;

    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;

    wire [3:0] dmem_strb;

    reg [31:0] dmem_rdata;


    wire halted;


 // DUT 
    rv32i_core DUT (

        .clk(clk),
        .reset(reset),

        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),

        .dmem_valid(dmem_valid),
        .dmem_write(dmem_write),

        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_strb(dmem_strb),

        .dmem_rdata(dmem_rdata),

        .halted(halted)

    );



    // INSTRUCTION MEMORY


    reg [31:0] imem [0:255];


    always @(*) begin

        imem_rdata =
            imem[imem_addr[9:2]];

    end


  
    // DATA MEMORY
    

    reg [31:0] dmem [0:255];


    always @(*) begin

        dmem_rdata =
            dmem[dmem_addr[9:2]];

    end


   
    // DATA MEMORY WRITE


    always @(posedge clk) begin

        if (dmem_valid && dmem_write) begin

            if (dmem_strb[0])

                dmem[dmem_addr[9:2]][7:0]
                    <= dmem_wdata[7:0];


            if (dmem_strb[1])

                dmem[dmem_addr[9:2]][15:8]
                    <= dmem_wdata[15:8];


            if (dmem_strb[2])

                dmem[dmem_addr[9:2]][23:16]
                    <= dmem_wdata[23:16];


            if (dmem_strb[3])

                dmem[dmem_addr[9:2]][31:24]
                    <= dmem_wdata[31:24];

        end

    end


    // CLOCK
    

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    
    // PROGRAM
 

    integer i;


    initial begin

        // --------------------------------------------------------
        // Clear memories
        // --------------------------------------------------------

        for (i = 0; i < 256; i = i + 1) begin

            imem[i] = 32'h00000013;

            dmem[i] = 32'h00000000;

        end


        // --------------------------------------------------------
        // Program
        // --------------------------------------------------------
        //
        // Address    Instruction
        //
        // 0x00       ADDI x1,x0,10
        // 0x04       ADDI x2,x0,20
        // 0x08       ADD  x3,x1,x2
        // 0x0C       SW   x3,0(x0)
        // 0x10       LW   x4,0(x0)
        // 0x14       ADDI x5,x4,5
        // 0x18       ECALL
        //
        // Expected:
        //
        // x1 = 10
        // x2 = 20
        // x3 = 30
        // x4 = 30
        // x5 = 35
        //
        // memory[0] = 30
        //
        // --------------------------------------------------------


        // ADDI x1,x0,10

        imem[0] =
            32'h00A00093;


        // ADDI x2,x0,20

        imem[1] =
            32'h01400113;


        // ADD x3,x1,x2

        imem[2] =
            32'h002081B3;


        // SW x3,0(x0)

        imem[3] =
            32'h00302023;


        // LW x4,0(x0)

        imem[4] =
            32'h00002203;


        // ADDI x5,x4,5

        imem[5] =
            32'h00520293;


        // ECALL

        imem[6] =
            32'h00000073;


        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        reset = 1'b1;

        #20;

        reset = 1'b0;

    end


   
    // DEBUG MONITOR
   

    always @(posedge clk) begin

        if (!reset) begin

            $display(
                "TIME=%0t PC=%08h INSTR=%08h x1=%0d x2=%0d x3=%0d x4=%0d x5=%0d",
                $time,
                DUT.pc,
                DUT.instr,
                DUT.REGFILE.regs[1],
                DUT.REGFILE.regs[2],
                DUT.REGFILE.regs[3],
                DUT.REGFILE.regs[4],
                DUT.REGFILE.regs[5]
            );

        end

    end


    
    // HALT
  

    always @(posedge halted) begin

        #10;

        $display("");
        $display("========================================");
        $display("        RV32I CPU HALTED");
        $display("========================================");

        $display("x1       = %0d",
                 DUT.REGFILE.regs[1]);

        $display("x2       = %0d",
                 DUT.REGFILE.regs[2]);

        $display("x3       = %0d",
                 DUT.REGFILE.regs[3]);

        $display("x4       = %0d",
                 DUT.REGFILE.regs[4]);

        $display("x5       = %0d",
                 DUT.REGFILE.regs[5]);

        $display("MEM[0]   = %0d",
                 dmem[0]);

        $display("========================================");

        $finish;

    end


    
    // TIMEOUT
    

    initial begin

        #500;

        $display("ERROR: Simulation timeout");

        $finish;

    end
    
    initial begin
    
    $dumpfile("RV32I.vcd");
    $dumpvars(0, tb_rv32i);
    
    end
    


endmodule
