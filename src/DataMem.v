module DataMem (
    input         clk,
    // 控制訊號 (來自 EX/MEM 管線暫存器)
    input         mem_read,
    input         mem_write,
    
    input  [31:0] addr,       // ALU 計算出的記憶體位址
    input  [31:0] write_data, // 準備寫入的資料 (通常是 rs2_data)
    output [31:0] read_data   // 讀出的資料 (準備送往 LD filter 或 MEM/WB 暫存器)
);

    reg [31:0] memory [0:1023];
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            memory[i] = 32'h00000000;
        end
    end

    // RISC-V 位址是 Byte-addressable，但陣列是 Word-addressable (每個元素 32-bit)。
    // 4KB 空間需要 12-bit 位址。捨棄最低 2 bit (addr[1:0])，取 addr[11:2] 作為陣列索引。
    wire [9:0] word_idx = addr[11:2];

    always @(posedge clk) begin
        if (mem_write) begin
            // 這裡暫時實作「寫入完整 Word (32-bit)」
            // 未來若要實作 SB/SH，可以在此處加上 Write Mask 機制
            memory[word_idx] <= write_data;
        end
    end

    assign read_data = (mem_read) ? memory[word_idx] : 32'd0;

endmodule