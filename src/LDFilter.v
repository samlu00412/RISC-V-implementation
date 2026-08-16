module LDFilter (
    input  [2:0]  load_type,   // 來自 ID 階段解碼出的 funct3 (用來判斷 LB, LH, LW 等)
    input  [1:0]  byte_offset, // 來自 ALU 計算出的記憶體位址最低兩位 addr[1:0]
    input  [31:0] raw_data,    // 來自 Dummy Memory / D-Cache 讀出的 32-bit 原始資料
    
    output reg [31:0] out_data 
);

    // =========================================================================
    // RISC-V Load 指令的 funct3 編碼對應表：
    // 3'b000: LB  (Load Byte, Sign-extended)
    // 3'b001: LH  (Load Halfword, Sign-extended)
    // 3'b010: LW  (Load Word) & FLW (Floating Load Word)
    // 3'b100: LBU (Load Byte, Zero-extended)
    // 3'b101: LHU (Load Halfword, Zero-extended)
    // =========================================================================

    always @(*) begin
        case (load_type) // synopsys parallel_case full_case
            
            // 1. LB (Load Byte - 有號擴展)
            3'b000: begin
                case (byte_offset)
                    2'b00: out_data = { {24{raw_data[7]}},  raw_data[7:0]   };
                    2'b01: out_data = { {24{raw_data[15]}}, raw_data[15:8]  };
                    2'b10: out_data = { {24{raw_data[23]}}, raw_data[23:16] };
                    2'b11: out_data = { {24{raw_data[31]}}, raw_data[31:24] };
                endcase
            end

            // 2. LH (Load Halfword - 有號擴展)
            // Halfword 必須 2-byte 對齊，只看 byte_offset[1]
            3'b001: begin
                if (byte_offset[1] == 1'b0)
                    out_data = { {16{raw_data[15]}}, raw_data[15:0]  }; // 取下半字 (Low Half)
                else
                    out_data = { {16{raw_data[31]}}, raw_data[31:16] }; // 取上半字 (High Half)
            end

            3'b010: begin
                out_data = raw_data;
            end

            3'b100: begin
                case (byte_offset)
                    2'b00: out_data = { 24'b0, raw_data[7:0]   };
                    2'b01: out_data = { 24'b0, raw_data[15:8]  };
                    2'b10: out_data = { 24'b0, raw_data[23:16] };
                    2'b11: out_data = { 24'b0, raw_data[31:24] };
                endcase
            end

            3'b101: begin
                if (byte_offset[1] == 1'b0)
                    out_data = { 16'b0, raw_data[15:0]  };
                else
                    out_data = { 16'b0, raw_data[31:16] };
            end
            default: begin
                out_data = raw_data;
            end
        endcase
    end

endmodule