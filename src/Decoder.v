module Decoder (
    input  [31:0] instruction,

    output [4:0]  rs1_addr,
    output [4:0]  rs2_addr,
    output [4:0]  rd_addr,
    output [2:0]  funct3,      // 供 LD Filter, Jump Unit, CSR 判斷使用

    output reg    reg_write,   // 是否寫回 Register File
    output reg    mem_to_reg,  // 0: 寫回 ALU/FPU 結果, 1: 寫回 Memory 讀出結果
    output reg    mem_read,    // 啟用 Data Memory 讀取
    output reg    mem_write,   // 啟用 Data Memory 寫入
    output reg    alu_src,     // ALU 來源 B (0: rs2_data, 1: imm)
    
    output reg    is_branch,   // 是否為 B-Type 分支指令
    output reg    is_jal,      // 是否為 JAL
    output reg    is_jalr,     // 是否為 JALR
    
    output [3:0]  alu_ctrl,    // 送給 IntegerALU 的 4-bit 控制碼
    output reg    is_mul,      // 啟用乘法器
    output reg [2:0] mul_ctrl, // 乘法器運算模式
    output reg    is_mac,      //  MAC.W (3 Read Ports 特殊指令)
    output reg    is_fpu,      // 啟用 FPU
    output reg [1:0] fpu_ctrl, // FPU 模式 (00:FADD, 01:FSUB, 10:FMIN, 11:FMAX)
    output reg    is_csr       // 啟用 CSR 暫存器讀寫
);

    // =========================================================================
    // 1. 欄位直取 (Direct Bit-Picking)
    // =========================================================================
    wire [6:0] opcode = instruction[6:0];
    wire [6:0] funct7 = instruction[31:25];
    
    assign funct3     = instruction[14:12];
    assign rs1_addr   = instruction[19:15];
    assign rs2_addr   = instruction[24:20];
    assign rd_addr    = instruction[11:7];

    // =========================================================================
    // 2. 主控制訊號狀態機
    // =========================================================================
    always @(*) begin
        reg_write  = 1'b0;
        mem_to_reg = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        alu_src    = 1'b0;
        is_branch  = 1'b0;
        is_jal     = 1'b0;
        is_jalr    = 1'b0;
        is_mul     = 1'b0;
        is_mac     = 1'b0;
        is_fpu     = 1'b0;
        is_csr     = 1'b0;
        
        mul_ctrl   = 3'b000;
        fpu_ctrl   = 2'b00;

        case (opcode) // synopsys parallel_case full_case
            // --- 基礎整數 ALU (R-Type) 與 乘法 (M-Extension) ---
            7'b0110011: begin
                reg_write = 1'b1;
                if (funct7 == 7'b0000001) begin // M-Extension 乘法
                    is_mul   = 1'b1;
                    mul_ctrl = funct3;
                end
            end
            
            // --- 基礎整數 ALU (I-Type) ---
            7'b0010011: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
            end
            
            // --- 記憶體讀取 (LW, LH, LB, LHU, LBU, FLW) ---
            7'b0000011, 7'b0000111: begin 
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1; 
                alu_src    = 1'b1; // 位址計算 (rs1 + imm)
            end
            
            // --- 記憶體寫入 (SW, SH, SB, FSW) ---
            7'b0100011, 7'b0100111: begin
                mem_write  = 1'b1;
                alu_src    = 1'b1; // 位址計算 (rs1 + imm)
            end
            
            7'b1100011: begin
                is_branch  = 1'b1;
            end
            
            // --- 跳躍並連結 (J-Type: JAL) ---
            7'b1101111: begin
                reg_write  = 1'b1;
                is_jal     = 1'b1;
            end
            
            // --- 暫存器跳躍 (I-Type: JALR) ---
            7'b1100111: begin
                reg_write  = 1'b1;
                is_jalr    = 1'b1;
                alu_src    = 1'b1; 
            end
            
            // --- 載入上限立即數 (U-Type: LUI, AUIPC) ---
            7'b0110111, 7'b0010111: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1; 
            end

            // --- 單精度浮點運算 (FPU OP) ---
            7'b1010011: begin
                reg_write  = 1'b1;
                is_fpu     = 1'b1;
                // 解析 FPU 控制訊號 (看 funct5 = instruction[31:27])
                if (instruction[31:27] == 5'b00000)      fpu_ctrl = 2'b00; // FADD.S
                else if (instruction[31:27] == 5'b00001) fpu_ctrl = 2'b01; // FSUB.S
                else if (instruction[31:27] == 5'b00101) fpu_ctrl = (funct3 == 3'b000) ? 2'b10 : 2'b11; // FMIN / FMAX
            end

            // --- MAC.W (自訂擴充指令) ---
            7'b0101011: begin
                reg_write  = 1'b1;
                is_mac     = 1'b1;
                is_mul     = 1'b1;   // 共用乘法器硬體
                mul_ctrl   = 3'b100; // 觸發 MAC 模式
            end

            // --- SYSTEM / CSR (RDCYCLE, RDINSTRET) ---
            7'b1110011: begin
                reg_write  = 1'b1;
                is_csr     = 1'b1;
            end
        endcase
    end

    // =========================================================================
    // 3. ALU 控制訊號 (零延遲平行映射)
    // =========================================================================
    // 嚴格過濾：只有「純 R-Type 整數運算」才是 funct7 == 0000000 或是 0100000
    // 避免把 MUL 或其他指令誤判為需要啟用 SRA 或 SUB
    wire is_rtype_alu = (opcode == 7'b0110011) && (funct7 == 7'b0000000 || funct7 == 7'b0100000);
    wire is_itype_alu = (opcode == 7'b0010011);
    
    // 第 4 個 Bit (用來區分 ADD/SUB, SRL/SRA)
    wire sub_sra_bit = (is_rtype_alu && instruction[30]) || 
                       (is_itype_alu && (funct3 == 3'b101) && instruction[30]);

    // 只有 R/I Type ALU 依賴 funct3，其他指令 (LW, SW, AUIPC...) 全部丟 4'b0000 給 ALU 做加法
    assign alu_ctrl = (is_rtype_alu || is_itype_alu) ? {sub_sra_bit, funct3} : 4'b0000;

endmodule