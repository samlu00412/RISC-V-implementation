module Multiplier (
    input  [31:0] rs1_data,
    input  [31:0] rs2_data,
    input  [31:0] rd_data,      //for mac.w
    input  [2:0]  mul_ctrl,    
    output [31:0] mul_out
);

    localparam MUL    = 3'b000;
    localparam MULH   = 3'b001;
    localparam MULHSU = 3'b010;
    localparam MULHU  = 3'b011;
    localparam MAC_W  = 3'b100; 

    wire is_rs1_signed = (mul_ctrl == MULH) || (mul_ctrl == MULHSU);
    wire is_rs2_signed = (mul_ctrl == MULH);

    wire signed [32:0] ext_rs1 = { (is_rs1_signed & rs1_data[31]), rs1_data };
    wire signed [32:0] ext_rs2 = { (is_rs2_signed & rs2_data[31]), rs2_data };
    wire signed [65:0] product = ext_rs1 * ext_rs2;

    reg [31:0] result;
    always @(*) begin
        case (mul_ctrl)
            MUL:      result = product[31:0];        
            MULH:     result = product[63:32];      
            MULHSU:   result = product[63:32];
            MULHU:    result = product[63:32];
            MAC_W:    result = product[31:0] + rd_data; 
            default:  result = 32'd0;
        endcase
    end

    assign mul_out = result;

endmodule