module ImmGen (
    input  [31:0] instruction,
    output reg [31:0] imm_out
);
    wire [6:0] opcode = instruction[6:0];

    always @(*) begin
        case (opcode) //synopsys parallel_case full_case
            7'b0010011, 7'b0000011, 7'b1100111, 7'b0000111: begin 
                imm_out = { {20{instruction[31]}}, instruction[31:20] };
            end
            7'b0100011, 7'b0100111: begin
                imm_out = { {20{instruction[31]}}, instruction[31:25], instruction[11:7] };
            end
            7'b1100011: begin
                imm_out = { {20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0 };
            end
            7'b0110111, 7'b0010111: begin
                imm_out = { instruction[31:12], 12'b0 };
            end
            7'b1101111: begin
                imm_out = { {12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0 };
            end
            default: imm_out = 32'b0;
        endcase
    end
endmodule