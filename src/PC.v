module PC (
    input clk,
    input rst,
    input pc_write,
    input [31:0] next_pc,
    output reg [31:0] address
);
    always @(posedge clk or posedge rst) begin
        if(rst) address <= 32'h00000000;
        else if(pc_write) begin
            address <= next_pc;
        end
    end
endmodule