module IntRegFile (
    input clk,
    input rst,
    
    input write_enable,
    input [4:0] write_reg,   // rd
    input [31:0] write_data,
    
    input [4:0] read_reg1,  // rs1
    output [31:0] read_data1,
    
    input [4:0] read_reg2,  // rs2
    output [31:0] read_data2
);
    
    reg [31:0] registers [31:0];
    integer i;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            for (i = 0; i < 32; i = i+1) begin
                registers[i] <= 32'h00000000;
            end
        end
        else begin
            if(write_enable) registers[write_reg] <= write_data;
        end
    end

    assign read_data1 = (write_enable && (write_reg == read_reg1)) ? write_data : registers[read_reg1];

    assign read_data2 = (write_enable && (write_reg == read_reg2)) ? write_data : registers[read_reg2];
    
endmodule