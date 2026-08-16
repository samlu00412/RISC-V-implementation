module DummyInstMem (
    input  [31:0] pc,        
    output [31:0] instruction  
);

    reg [31:0] rom [0:1023];
    initial begin
        // 請確保 "prog.hex" 檔案與你的 Testbench 或專案執行路徑在同一個目錄下。
        $readmemh("prog.hex", rom);
    end

    // 因此忽略 pc[1:0]，直接取 pc[11:2] 作為讀取索引，避免位址不對齊。
    wire [9:0] word_idx = pc[11:2];
    assign instruction = rom[word_idx];

endmodule