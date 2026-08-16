module JumpUnit (
    input         is_branch, 
    input         is_jal,    
    input         is_jalr,   
    input  [2:0]  branch_op, 

    input  [31:0] pc,       
    input  [31:0] imm,       
    input  [31:0] rs1_data,  
    input  [31:0] rs2_data, 

    output        jump_taken, 
    output [31:0] jump_addr, 
    output [31:0] link_pc    
);

    reg branch_hit;
    
    always @(*) begin
        if (is_branch) begin
            case (branch_op)
                3'b000: branch_hit = (rs1_data == rs2_data);
                3'b001: branch_hit = (rs1_data != rs2_data);
                3'b100: branch_hit = ($signed(rs1_data) < $signed(rs2_data));
                3'b101: branch_hit = ($signed(rs1_data) >= $signed(rs2_data));
                3'b110: branch_hit = (rs1_data < rs2_data); // Unsigned
                3'b111: branch_hit = (rs1_data >= rs2_data); // Unsigned
                default: branch_hit = 1'b0;
            endcase
        end else begin
            branch_hit = 1'b0;
        end
    end

    assign jump_taken = branch_hit | is_jal | is_jalr;

    wire [31:0] base_addr = is_jalr ? rs1_data : pc;
    wire [31:0] target_sum = base_addr + imm;

    assign jump_addr = is_jalr ? {target_sum[31:1], 1'b0} : target_sum;
    assign link_pc = pc + 32'd4;

endmodule