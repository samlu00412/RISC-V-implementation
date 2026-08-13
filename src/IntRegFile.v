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
    
endmodule