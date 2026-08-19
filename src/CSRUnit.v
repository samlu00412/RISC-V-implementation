module CSRUnit (
    input         clk,
    input         rst,
    
    input         is_csr,      
    input  [2:0]  funct3,     
    input  [11:0] csr_addr,     // 來自 instruction[31:20]，用來區分讀取哪一個 CSR
    output reg [31:0] csr_read_data
);

    reg [63:0] cycle_counter;
    reg [63:0] instret_counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle_counter   <= 64'd0;
            instret_counter <= 64'd0;
        end else begin
            cycle_counter   <= cycle_counter + 64'd1;
            // 嚴謹的 instret 應該是「每退役一條有效指令加 1」，
            // 初期測試階段可以簡單處理，先讓它跟隨 cycle 增加
            instret_counter <= instret_counter + 64'd1; 
        end
    end

    // 0xC00 = cycle, 0xC80 = cycleh, 0xC02 = instret, 0xC82 = instreth
    always @(*) begin
        if (is_csr) begin
            case (csr_addr)
                12'hC00: csr_read_data = cycle_counter[31:0];
                12'hC80: csr_read_data = cycle_counter[63:32];
                12'hC02: csr_read_data = instret_counter[31:0];
                12'hC82: csr_read_data = instret_counter[63:32];
                default: csr_read_data = 32'd0;
            endcase
        end else begin
            csr_read_data = 32'd0;
        end
    end

endmodule