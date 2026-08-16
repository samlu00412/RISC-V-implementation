module FPU (
    input         clk,
    input         rst,
    
    input         fpu_enable, // 為 1 時代表當前 EX 階段是 FPU 指令
    input  [1:0]  fpu_ctrl,   // 2'b00: FADD, 2'b01: FSUB, 2'b10: FMIN, 2'b11: FMAX
    input  [31:0] operand_a,
    input  [31:0] operand_b,
    
    output [31:0] fpu_out,    // FPU 運算結果
    output        fpu_stall   // 送給 Hazard Unit：為 1 時暫停前半段管線
);

    // =========================================================================
    // 0. 控制訊號解析
    // =========================================================================
    wire is_add_sub = (fpu_ctrl == 2'b00) || (fpu_ctrl == 2'b01);
    wire is_fmin    = (fpu_ctrl == 2'b10);
    wire is_fmax    = (fpu_ctrl == 2'b11);
    
    // 處理 FSUB 的符號反轉
    wire [31:0] b_eff = (fpu_ctrl == 2'b01) ? {~operand_b[31], operand_b[30:0]} : operand_b;

    // 狀態機：0 = 執行 Cycle 1 (或組合邏輯), 1 = 執行 Cycle 2
    reg fpu_state;
    always @(posedge clk or posedge rst) begin
        if (rst) 
            fpu_state <= 1'b0;
        else if (fpu_enable && is_add_sub && fpu_state == 1'b0)
            fpu_state <= 1'b1; // 進入 Cycle 2
        else
            fpu_state <= 1'b0; // 算完或非 FPU 指令，回到 Cycle 1 狀態
    end

    // 只有在執行 FADD/FSUB 的第 1 個 Cycle 時，才發出 stall 請求
    assign fpu_stall = (fpu_enable && is_add_sub && fpu_state == 1'b0);

    // =========================================================================
    // 1. FMIN / FMAX 快速比較器 (組合邏輯，1 個 Cycle 內完成)
    // =========================================================================
    wire sign_a = operand_a[31];
    wire sign_b = operand_b[31];
    wire [30:0] mag_a = operand_a[30:0];
    wire [30:0] mag_b = operand_b[30:0];
    
    wire a_lt_b = (sign_a != sign_b) ? sign_a : 
                  (sign_a) ? (mag_a > mag_b) : (mag_a < mag_b);

    wire [31:0] fmin_res = a_lt_b ? operand_a : operand_b;
    wire [31:0] fmax_res = a_lt_b ? operand_b : operand_a;


    // =========================================================================
    // 2. FADD / FSUB: Cycle 1 (拆解、絕對值比較、指數對齊)
    // =========================================================================
    // 找出絕對值較大者，以決定最終結果的符號，並將小數的尾數右移對齊
    wire a_mag_gt_b_mag = (mag_a > b_eff[30:0]);
    wire [31:0] op_lg = a_mag_gt_b_mag ? operand_a : b_eff;
    wire [31:0] op_sm = a_mag_gt_b_mag ? b_eff : operand_a;

    // FTZ (Flush-To-Zero)：如果指數為 0 (Subnormal)，直接當 0 處理
    wire [23:0] fract_lg = (op_lg[30:23] == 0) ? 24'b0 : {1'b1, op_lg[22:0]};
    wire [23:0] fract_sm = (op_sm[30:23] == 0) ? 24'b0 : {1'b1, op_sm[22:0]};
    
    wire [7:0] exp_diff = op_lg[30:23] - op_sm[30:23];
    
    // 將小數位的尾數右移對齊 (增加 4 個保護位元 Guard bits 來提高精確度)
    wire [27:0] fract_lg_ext = {fract_lg, 4'b0000};
    wire [27:0] fract_sm_ext = {fract_sm, 4'b0000} >> (exp_diff > 28 ? 28 : exp_diff);

    // 決定是做加法還是減法
    wire eff_op_sub = op_lg[31] ^ op_sm[31];
    
    // --- Pipeline Registers (EX1 -> EX2) ---
    reg        p_eff_op_sub;
    reg        p_res_sign;
    reg [7:0]  p_common_exp;
    reg [27:0] p_fract_lg;
    reg [27:0] p_fract_sm;

    always @(posedge clk) begin
        if (fpu_enable && is_add_sub && fpu_state == 1'b0) begin
            p_eff_op_sub <= eff_op_sub;
            p_res_sign   <= op_lg[31];
            p_common_exp <= op_lg[30:23];
            p_fract_lg   <= fract_lg_ext;
            p_fract_sm   <= fract_sm_ext;
        end
    end

    // =========================================================================
    // 3. FADD / FSUB: Cycle 2 (尾數加減、LZC 找前導零、正規化)
    // =========================================================================
    // 29-bit 加減法 (多 1 bit 裝溢位 Overflow)
    wire [28:0] sum = p_eff_op_sub ? (p_fract_lg - p_fract_sm) : (p_fract_lg + p_fract_sm);

    // 尋找前導零 (LZC - Leading Zero Counter)
    // 對於 28-bit 的尾數，使用平行優先權選擇器，合成後是一棵延遲極低的邏輯樹
    reg [4:0] lzc;
    always @(*) begin
             if (sum[27]) lzc = 5'd0;
        else if (sum[26]) lzc = 5'd1;
        else if (sum[25]) lzc = 5'd2;
        else if (sum[24]) lzc = 5'd3;
        else if (sum[23]) lzc = 5'd4;
        else if (sum[22]) lzc = 5'd5;
        else if (sum[21]) lzc = 5'd6;
        else if (sum[20]) lzc = 5'd7;
        else if (sum[19]) lzc = 5'd8;
        else if (sum[18]) lzc = 5'd9;
        else if (sum[17]) lzc = 5'd10;
        else if (sum[16]) lzc = 5'd11;
        else if (sum[15]) lzc = 5'd12;
        else if (sum[14]) lzc = 5'd13;
        else if (sum[13]) lzc = 5'd14;
        else if (sum[12]) lzc = 5'd15;
        else if (sum[11]) lzc = 5'd16;
        else if (sum[10]) lzc = 5'd17;
        else if (sum[ 9]) lzc = 5'd18;
        else if (sum[ 8]) lzc = 5'd19;
        else if (sum[ 7]) lzc = 5'd20;
        else if (sum[ 6]) lzc = 5'd21;
        else if (sum[ 5]) lzc = 5'd22;
        else if (sum[ 4]) lzc = 5'd23;
        else              lzc = 5'd24; 
    end

    wire [28:0] norm_sum;
    wire [7:0]  norm_exp;

    // 正規化 (Normalization) 邏輯
    assign norm_sum = sum[28] ? (sum >> 1) : (sum << lzc);
    assign norm_exp = (sum == 0) ? 8'd0 : 
                      (sum[28])  ? (p_common_exp + 1'b1) : (p_common_exp - lzc);

    // 捨入 (這裡採用精簡版捨入：直接看進位保護 bit)
    wire round_bit = norm_sum[3];
    wire [22:0] final_fract = norm_sum[26:4] + round_bit;
    
    // 組裝 FADD/FSUB 結果
    wire [31:0] fadd_sub_res = (norm_exp == 0) ? 32'b0 : {p_res_sign, norm_exp, final_fract};


    // =========================================================================
    // 4. 最終結果多工器 (MUX)
    // =========================================================================
    assign fpu_out = is_fmin ? fmin_res :
                     is_fmax ? fmax_res :
                     fadd_sub_res; // FADD/FSUB 只有在 Cycle 2 結束時，這個輸出才有意義

endmodule