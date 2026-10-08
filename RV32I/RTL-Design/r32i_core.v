`timescale 1ns/1ps

module rv32i_core (

    input         clk,
    input         reset,

    // ============================================================
    // Instruction memory
    // ============================================================

    output [31:0] imem_addr,
    input  [31:0] imem_rdata,

    // ============================================================
    // Data memory
    // ============================================================

    output        dmem_valid,
    output        dmem_write,
    output [31:0] dmem_addr,
    output [31:0] dmem_wdata,
    output [3:0]  dmem_strb,

    input  [31:0] dmem_rdata,

    // ============================================================
    // Status
    // ============================================================

    output        halted

);


    // ============================================================
    // OPCODES
    // ============================================================

    localparam OPCODE_LUI     = 7'b0110111;
    localparam OPCODE_AUIPC   = 7'b0010111;
    localparam OPCODE_JAL     = 7'b1101111;
    localparam OPCODE_JALR    = 7'b1100111;
    localparam OPCODE_BRANCH  = 7'b1100011;
    localparam OPCODE_LOAD    = 7'b0000011;
    localparam OPCODE_STORE   = 7'b0100011;
    localparam OPCODE_OP_IMM = 7'b0010011;
    localparam OPCODE_OP      = 7'b0110011;
    localparam OPCODE_FENCE   = 7'b0001111;
    localparam OPCODE_SYSTEM  = 7'b1110011;


    // ============================================================
    // ALU CONTROL
    // ============================================================

    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_SLL  = 4'd2;
    localparam ALU_SLT  = 4'd3;
    localparam ALU_SLTU = 4'd4;
    localparam ALU_XOR  = 4'd5;
    localparam ALU_SRL  = 4'd6;
    localparam ALU_SRA  = 4'd7;
    localparam ALU_OR   = 4'd8;
    localparam ALU_AND  = 4'd9;


    // ============================================================
    // PROGRAM COUNTER
    // ============================================================

    reg [31:0] pc;
    reg [31:0] next_pc;

    assign imem_addr = pc;


    // ============================================================
    // INSTRUCTION
    // ============================================================

    wire [31:0] instr;

    assign instr = imem_rdata;


    // ============================================================
    // INSTRUCTION FIELDS
    // ============================================================

    wire [6:0] opcode;
    wire [4:0] rd;
    wire [2:0] funct3;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [6:0] funct7;

    assign opcode = instr[6:0];

    assign rd     = instr[11:7];

    assign funct3 = instr[14:12];

    assign rs1    = instr[19:15];

    assign rs2    = instr[24:20];

    assign funct7 = instr[31:25];


    // ============================================================
    // IMMEDIATES
    // ============================================================

    wire [31:0] imm_i;
    wire [31:0] imm_s;
    wire [31:0] imm_b;
    wire [31:0] imm_u;
    wire [31:0] imm_j;

    rv32i_imm_gen IMM_GEN (

        .instr(instr),

        .imm_i(imm_i),
        .imm_s(imm_s),
        .imm_b(imm_b),
        .imm_u(imm_u),
        .imm_j(imm_j)

    );


    // ============================================================
    // REGISTER FILE
    // ============================================================

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    reg         reg_write;

    reg [31:0]  writeback_data;


    rv32i_regfile REGFILE (

        .clk(clk),
        .reset(reset),

        .rs1(rs1),
        .rs2(rs2),

        .rs1_data(rs1_data),
        .rs2_data(rs2_data),

        .reg_write(reg_write),
        .rd(rd),
        .rd_data(writeback_data)

    );


    // ============================================================
    // CONTROL SIGNALS
    // ============================================================

    reg alu_src_imm;

    reg mem_read;
    reg mem_write;

    reg mem_to_reg;

    reg branch;
    reg jump;
    reg jump_reg;

    reg is_lui;
    reg is_auipc;

    reg illegal_instr;

    reg [3:0] alu_ctrl;


    // ============================================================
    // MEMORY SIZE
    // ============================================================

    localparam SIZE_BYTE = 2'd0;
    localparam SIZE_HALF = 2'd1;
    localparam SIZE_WORD = 2'd2;

    reg [1:0] mem_size;

    reg load_unsigned;


    // ============================================================
    // MAIN DECODER
    // ============================================================

    always @(*) begin

        // --------------------------------------------------------
        // Defaults
        // --------------------------------------------------------

        reg_write     = 1'b0;

        alu_src_imm   = 1'b0;

        mem_read      = 1'b0;
        mem_write     = 1'b0;

        mem_to_reg    = 1'b0;

        branch        = 1'b0;

        jump          = 1'b0;
        jump_reg      = 1'b0;

        is_lui        = 1'b0;
        is_auipc      = 1'b0;

        illegal_instr = 1'b0;

        alu_ctrl      = ALU_ADD;

        mem_size      = SIZE_WORD;

        load_unsigned = 1'b0;


        case (opcode)

            // ====================================================
            // LUI
            // ====================================================

            OPCODE_LUI: begin

                reg_write   = 1'b1;

                alu_src_imm = 1'b1;

                is_lui      = 1'b1;

            end


            // ====================================================
            // AUIPC
            // ====================================================

            OPCODE_AUIPC: begin

                reg_write   = 1'b1;

                alu_src_imm = 1'b1;

                is_auipc    = 1'b1;

            end


            // ====================================================
            // JAL
            // ====================================================

            OPCODE_JAL: begin

                reg_write = 1'b1;

                jump = 1'b1;

            end


            // ====================================================
            // JALR
            // ====================================================

            OPCODE_JALR: begin

                if (funct3 == 3'b000) begin

                    reg_write   = 1'b1;

                    jump_reg    = 1'b1;

                    alu_src_imm = 1'b1;

                end

                else begin

                    illegal_instr = 1'b1;

                end

            end


            // ====================================================
            // BRANCH
            // ====================================================

            OPCODE_BRANCH: begin

                branch = 1'b1;

                case (funct3)

                    3'b000: ; // BEQ
                    3'b001: ; // BNE
                    3'b100: ; // BLT
                    3'b101: ; // BGE
                    3'b110: ; // BLTU
                    3'b111: ; // BGEU

                    default:
                        illegal_instr = 1'b1;

                endcase

            end


            // ====================================================
            // LOAD
            // ====================================================

            OPCODE_LOAD: begin

                reg_write   = 1'b1;

                alu_src_imm = 1'b1;

                mem_read    = 1'b1;

                mem_to_reg  = 1'b1;

                alu_ctrl    = ALU_ADD;


                case (funct3)

                    // LB
                    3'b000: begin

                        mem_size      = SIZE_BYTE;

                        load_unsigned = 1'b0;

                    end


                    // LH
                    3'b001: begin

                        mem_size      = SIZE_HALF;

                        load_unsigned = 1'b0;

                    end


                    // LW
                    3'b010: begin

                        mem_size      = SIZE_WORD;

                        load_unsigned = 1'b0;

                    end


                    // LBU
                    3'b100: begin

                        mem_size      = SIZE_BYTE;

                        load_unsigned = 1'b1;

                    end


                    // LHU
                    3'b101: begin

                        mem_size      = SIZE_HALF;

                        load_unsigned = 1'b1;

                    end


                    default:
                        illegal_instr = 1'b1;

                endcase

            end


            // ====================================================
            // STORE
            // ====================================================

            OPCODE_STORE: begin

                alu_src_imm = 1'b1;

                mem_write   = 1'b1;

                alu_ctrl    = ALU_ADD;


                case (funct3)

                    // SB
                    3'b000:
                        mem_size = SIZE_BYTE;


                    // SH
                    3'b001:
                        mem_size = SIZE_HALF;


                    // SW
                    3'b010:
                        mem_size = SIZE_WORD;


                    default:
                        illegal_instr = 1'b1;

                endcase

            end


            // ====================================================
            // OP-IMM
            // ====================================================

            OPCODE_OP_IMM: begin

                reg_write   = 1'b1;

                alu_src_imm = 1'b1;


                case (funct3)

                    // ADDI
                    3'b000:
                        alu_ctrl = ALU_ADD;


                    // SLLI
                    3'b001: begin

                        if (funct7 == 7'b0000000)
                            alu_ctrl = ALU_SLL;

                        else
                            illegal_instr = 1'b1;

                    end


                    // SLTI
                    3'b010:
                        alu_ctrl = ALU_SLT;


                    // SLTIU
                    3'b011:
                        alu_ctrl = ALU_SLTU;


                    // XORI
                    3'b100:
                        alu_ctrl = ALU_XOR;


                    // SRLI / SRAI
                    3'b101: begin

                        if (funct7 == 7'b0000000)
                            alu_ctrl = ALU_SRL;

                        else if (funct7 == 7'b0100000)
                            alu_ctrl = ALU_SRA;

                        else
                            illegal_instr = 1'b1;

                    end


                    // ORI
                    3'b110:
                        alu_ctrl = ALU_OR;


                    // ANDI
                    3'b111:
                        alu_ctrl = ALU_AND;


                    default:
                        illegal_instr = 1'b1;

                endcase

            end


            // ====================================================
            // OP
            // ====================================================

            OPCODE_OP: begin

                reg_write = 1'b1;


                case (funct3)

                    // ADD / SUB
                    3'b000: begin

                        if (funct7 == 7'b0000000)

                            alu_ctrl = ALU_ADD;

                        else if (funct7 == 7'b0100000)

                            alu_ctrl = ALU_SUB;

                        else

                            illegal_instr = 1'b1;

                    end


                    // SLL
                    3'b001: begin

                        if (funct7 == 7'b0000000)

                            alu_ctrl = ALU_SLL;

                        else

                            illegal_instr = 1'b1;

                    end


                    // SLT
                    3'b010: begin

                        if (funct7 == 7'b0000000)

                            alu_ctrl = ALU_SLT;

                        else

                            illegal_instr = 1'b1;

                    end


                    // SLTU
                    3'b011: begin

                        if (funct7 == 7'b0000000)

                            alu_ctrl = ALU_SLTU;

                        else

                            illegal_instr = 1'b1;

                    end


                    // XOR
                    3'b100: begin

                        if (funct7 == 7'b0000000)

                            alu_ctrl = ALU_XOR;

                        else

                            illegal_instr = 1'b1;

                    end


                    // SRL / SRA
                    3'b101: begin

                        if (funct7 == 7'b0000000)

                            alu_ctrl = ALU_SRL;

                        else if (funct7 == 7'b0100000)

                            alu_ctrl = ALU_SRA;

                        else

                            illegal_instr = 1'b1;

                    end


                    // OR
                    3'b110: begin

                        if (funct7 == 7'b0000000)

                            alu_ctrl = ALU_OR;

                        else

                            illegal_instr = 1'b1;

                    end


                    // AND
                    3'b111: begin

                        if (funct7 == 7'b0000000)

                            alu_ctrl = ALU_AND;

                        else

                            illegal_instr = 1'b1;

                    end


                    default:
                        illegal_instr = 1'b1;

                endcase

            end


            // ====================================================
            // FENCE
            // ====================================================

            OPCODE_FENCE: begin

                // Simplified implementation:
                // FENCE behaves as NOP.

            end


            // ====================================================
            // SYSTEM
            // ====================================================

            OPCODE_SYSTEM: begin

                // Only ECALL / EBREAK are recognized here.

                if (funct3 == 3'b000) begin

                    if ((instr[31:20] == 12'h000) ||
                        (instr[31:20] == 12'h001)) begin

                        // ECALL / EBREAK

                    end

                    else begin

                        illegal_instr = 1'b1;

                    end

                end

                else begin

                    // CSR instructions not implemented

                    illegal_instr = 1'b1;

                end

            end


            // ====================================================
            // INVALID
            // ====================================================

            default: begin

                illegal_instr = 1'b1;

            end

        endcase

    end


    // ============================================================
    // ALU INPUTS
    // ============================================================

    reg [31:0] alu_a;
    reg [31:0] alu_b;

    wire [31:0] alu_result;


    always @(*) begin

        alu_a = rs1_data;

        if (alu_src_imm)
            alu_b = imm_i;
        else
            alu_b = rs2_data;


        // LUI
        if (is_lui) begin

            alu_a = 32'd0;

            alu_b = imm_u;

        end


        // AUIPC
        if (is_auipc) begin

            alu_a = pc;

            alu_b = imm_u;

        end

    end


    rv32i_alu ALU (

        .a(alu_a),
        .b(alu_b),
        .alu_ctrl(alu_ctrl),
        .y(alu_result)

    );


    // ============================================================
    // BRANCH COMPARATOR
    // ============================================================

    reg branch_taken;


    always @(*) begin

        branch_taken = 1'b0;


        if (branch) begin

            case (funct3)

                // BEQ
                3'b000:

                    branch_taken =
                        (rs1_data == rs2_data);


                // BNE
                3'b001:

                    branch_taken =
                        (rs1_data != rs2_data);


                // BLT
                3'b100:

                    branch_taken =
                        ($signed(rs1_data) <
                         $signed(rs2_data));


                // BGE
                3'b101:

                    branch_taken =
                        ($signed(rs1_data) >=
                         $signed(rs2_data));


                // BLTU
                3'b110:

                    branch_taken =
                        (rs1_data < rs2_data);


                // BGEU
                3'b111:

                    branch_taken =
                        (rs1_data >= rs2_data);


                default:

                    branch_taken = 1'b0;

            endcase

        end

    end


    // ============================================================
    // NEXT PC
    // ============================================================

    always @(*) begin

        // Normal execution

        next_pc = pc + 32'd4;


        // Taken branch

        if (branch && branch_taken)

            next_pc = pc + imm_b;


        // JAL

        if (jump)

            next_pc = pc + imm_j;


        // JALR

        if (jump_reg)

            next_pc =
                (rs1_data + imm_i) &
                32'hFFFFFFFE;

    end


    // ============================================================
    // DATA MEMORY
    // ============================================================

    reg [3:0] store_strb;


    assign dmem_valid =
        mem_read | mem_write;


    assign dmem_write =
        mem_write;


    assign dmem_addr =
        alu_result;


    assign dmem_wdata =
        rs2_data;


    assign dmem_strb =
        store_strb;


    always @(*) begin

        store_strb = 4'b0000;


        if (mem_write) begin

            case (mem_size)

                // ------------------------------------------------
                // SB
                // ------------------------------------------------

                SIZE_BYTE: begin

                    case (alu_result[1:0])

                        2'b00:
                            store_strb = 4'b0001;

                        2'b01:
                            store_strb = 4'b0010;

                        2'b10:
                            store_strb = 4'b0100;

                        2'b11:
                            store_strb = 4'b1000;

                    endcase

                end


                // ------------------------------------------------
                // SH
                // ------------------------------------------------

                SIZE_HALF: begin

                    if (alu_result[1] == 1'b0)

                        store_strb = 4'b0011;

                    else

                        store_strb = 4'b1100;

                end


                // ------------------------------------------------
                // SW
                // ------------------------------------------------

                SIZE_WORD:

                    store_strb = 4'b1111;


                default:

                    store_strb = 4'b0000;

            endcase

        end

    end


    // ============================================================
    // LOAD DATA
    // ============================================================

    reg [31:0] load_data;


    always @(*) begin

        load_data = 32'd0;


        case (mem_size)

            // ----------------------------------------------------
            // BYTE
            // ----------------------------------------------------

            SIZE_BYTE: begin

                case (alu_result[1:0])

                    2'b00: begin

                        if (load_unsigned)

                            load_data =
                                {24'd0,
                                 dmem_rdata[7:0]};

                        else

                            load_data =
                                {{24{dmem_rdata[7]}},
                                 dmem_rdata[7:0]};

                    end


                    2'b01: begin

                        if (load_unsigned)

                            load_data =
                                {24'd0,
                                 dmem_rdata[15:8]};

                        else

                            load_data =
                                {{24{dmem_rdata[15]}},
                                 dmem_rdata[15:8]};

                    end


                    2'b10: begin

                        if (load_unsigned)

                            load_data =
                                {24'd0,
                                 dmem_rdata[23:16]};

                        else

                            load_data =
                                {{24{dmem_rdata[23]}},
                                 dmem_rdata[23:16]};

                    end


                    2'b11: begin

                        if (load_unsigned)

                            load_data =
                                {24'd0,
                                 dmem_rdata[31:24]};

                        else

                            load_data =
                                {{24{dmem_rdata[31]}},
                                 dmem_rdata[31:24]};

                    end

                endcase

            end


            // ----------------------------------------------------
            // HALF
            // ----------------------------------------------------

            SIZE_HALF: begin

                if (alu_result[1] == 1'b0) begin

                    if (load_unsigned)

                        load_data =
                            {16'd0,
                             dmem_rdata[15:0]};

                    else

                        load_data =
                            {{16{dmem_rdata[15]}},
                             dmem_rdata[15:0]};

                end

                else begin

                    if (load_unsigned)

                        load_data =
                            {16'd0,
                             dmem_rdata[31:16]};

                    else

                        load_data =
                            {{16{dmem_rdata[31]}},
                             dmem_rdata[31:16]};

                end

            end


            // ----------------------------------------------------
            // WORD
            // ----------------------------------------------------

            SIZE_WORD:

                load_data = dmem_rdata;


            default:

                load_data = 32'd0;

        endcase

    end


    // ============================================================
    // WRITEBACK
    // ============================================================

    always @(*) begin

        writeback_data = alu_result;


        // Load instructions

        if (mem_to_reg)

            writeback_data = load_data;


        // JAL / JALR

        if (jump || jump_reg)

            writeback_data = pc + 32'd4;

    end


    // ============================================================
    // HALT
    // ============================================================

    reg halt_instruction;

    always @(*) begin

        halt_instruction = 1'b0;


        if (opcode == OPCODE_SYSTEM) begin

            if (funct3 == 3'b000) begin

                if ((instr[31:20] == 12'h000) ||
                    (instr[31:20] == 12'h001))

                    halt_instruction = 1'b1;

            end

        end

    end


    reg halted_reg;

    assign halted = halted_reg;


    // ============================================================
    // PC UPDATE
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            pc         <= 32'h00000000;

            halted_reg <= 1'b0;

        end

        else begin

            if (!halted_reg) begin

                if (halt_instruction) begin

                    halted_reg <= 1'b1;

                end

                else if (illegal_instr) begin

                    halted_reg <= 1'b1;

                end

                else begin

                    pc <= next_pc;

                end

            end

        end

    end


endmodule
