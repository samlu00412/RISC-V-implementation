module ALU (
    input [31:0] operand_a,
    input [31:0] operand_b,
    input [3:0] alu_ctrl,
    output reg [31:0] result,
    output zero
);
    localparam ALU_ADD  = 4'b0000; // 0: ADD, ADDI, LW, SW, AUIPC, LUI
    localparam ALU_SUB  = 4'b1000; // 8: SUB
    localparam ALU_SLL  = 4'b0001; // 1: SLL, SLLI
    localparam ALU_SLT  = 4'b0010; // 2: SLT, SLTI (Signed)
    localparam ALU_SLTU = 4'b0011; // 3: SLTU, SLTIU (Unsigned)
    localparam ALU_XOR  = 4'b0100; // 4: XOR, XORI
    localparam ALU_SRL  = 4'b0101; // 5: SRL, SRLI (Logical Shift)
    localparam ALU_SRA  = 4'b1101; // 13: SRA, SRAI (Arithmetic Shift)
    localparam ALU_OR   = 4'b0110; // 6: OR, ORI
    localparam ALU_AND  = 4'b0111; // 7: AND, ANDI

    wire [4:0] shamt = operand_b[4:0];

    always @(*) begin
        case (alu_ctrl) // synopsys parallel_case full_case
            ALU_ADD: begin
                alu_out = operand_a + operand_b;
            end
            ALU_SUB: begin
                alu_out = operand_a - operand_b;
            end
            ALU_SLL: begin
                alu_out = operand_a << shamt;
            end
            ALU_SLT: begin
                alu_out = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;
            end
            ALU_SLTU: begin
                alu_out = (operand_a < operand_b) ? 32'd1 : 32'd0;
            end
            ALU_XOR: begin
                alu_out = operand_a ^ operand_b;
            end
            ALU_SRL: begin
                alu_out = operand_a >> shamt;
            end
            ALU_SRA: begin
                alu_out = $signed(operand_a) >>> shamt;
            end
            ALU_OR: begin
                alu_out = operand_a | operand_b;
            end
            ALU_AND: begin
                alu_out = operand_a & operand_b;
            end
            default: begin
                alu_out = 32'd0;
            end
        endcase
    end

    assign zero = (alu_out == 32'd0);
endmodule