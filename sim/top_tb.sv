//******************************************************************************
// Copyright (c) 2025 Tsai Yu-Chen (Neo)
// Low Power and High Performance (LPHP) Laboratory
// Advisor: Prof. Lih-Yih, Chiou
// All Rights Reserved.
//
// This source code is developed at LPHP Lab.
// Unauthorized copying, distribution, modification, or use of this code
// without explicit written permission from the advisor is strictly prohibited.
//
// File        : top_tb.sv
// Author      : Tsai Yu-Chen (Neo)
// Course      : VLSI System Design
// Advisor     : Prof. Lih-Yih, Chiou
// Created     : 2025/11/21
// Version     : 1.0
// Description : testbench
//******************************************************************************
`timescale 1ns/10ps
`define CYCLE 10.0      // Cycle time
`define MAX 10000000    // Max cycle number

`ifdef SYN
    `include "top_syn.v"
    `include "data_array/data_array_rtl.sv"
    `include "tag_array/tag_array_rtl.sv"
    `include "/usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v"
    `include "/usr/cad/CBDK/Executable_Package/Collaterals/IP/stdio/N16ADFP_StdIO/VERILOG/N16ADFP_StdIO.v"
`else
    `include "top.v"
    `include "data_array/data_array_rtl.sv"
    `include "tag_array/tag_array_rtl.sv"
    
`endif

`include "/System/bus.svp"
`include "/System/bus_interface.svh"
`include "/System/DRAM.svp"
`include "/System/UART.svp"

`define dram_word(addr) \
  {u_dram.MEM6[addr*4+3], \
   u_dram.MEM6[addr*4+2], \
   u_dram.MEM6[addr*4+1], \
   u_dram.MEM6[addr*4]}

`timescale 1ns/10ps
`define SIM_END 'h3fff
`define SIM_RDCYCLE 'h3ffb
`define SIM_RDINST  'h3ffd
`define SIM_END_CODE -32'd1
`define TEST_START 'h0000

`include "sim_pkg.sv"
import sim_pkg::*;

module top_tb;

    logic clk;
    logic rst;
    logic [31:0] GOLDEN[4096];
    integer gf, i, num ,a ,b ,c, code;
    integer err;
    integer cycle_err;
    logic [63:0]total_cycle ;
    longint unsigned inst_cnt;
    longint unsigned cyc_cnt;
    real cpi;
    real t;
    string prog_path;
    string rdcycle;
    always #(`CYCLE/2) clk = ~clk;
    //=================================================================
    // SYSTEM Module Connection
    //=================================================================
    bus_if IM_bus();
    bus_if DM_bus();
    bus_if DRAM_bus();
    bus_if UART_bus();

    top u_top(
        .clk        (clk),
        .rst        (rst),
        .ARADDR_IM  (IM_bus.ARADDR),
        .ARVALID_IM (IM_bus.ARVALID),
        .ARREADY_IM (IM_bus.ARREADY),

        .RDATA_IM   (IM_bus.RDATA),
        .RVALID_IM  (IM_bus.RVALID),
        .RREADY_IM  (IM_bus.RREADY),

        .ARADDR_DM  (DM_bus.ARADDR),
        .ARVALID_DM (DM_bus.ARVALID),
        .ARREADY_DM (DM_bus.ARREADY),

        .RDATA_DM   (DM_bus.RDATA),
        .RVALID_DM  (DM_bus.RVALID),
        .RREADY_DM  (DM_bus.RREADY),

        .AWADDR_DM  (DM_bus.AWADDR),
        .AWVALID_DM (DM_bus.AWVALID),
        .AWREADY_DM (DM_bus.AWREADY),

        .WDATA_DM   (DM_bus.WDATA),
        .WSTRB_DM   (DM_bus.WSTRB),
        .WVALID_DM  (DM_bus.WVALID),
        .WREADY_DM  (DM_bus.WREADY)
    );

    BUS u_bus(
        .clk(clk),
        .rst(rst),
        .im_io(IM_bus),
        .dm_io(DM_bus),
        .dram_io(DRAM_bus),
        .uart_io(UART_bus)
    );

    DRAM u_dram(
        .clk(clk),
        .rst(rst),
        .bus_io(DRAM_bus)
    );

    UART_SENDER u_sender(
        .clk(clk),
        .rst(rst),
        .bus_io(UART_bus)
    );

    //=================================================================
    // Simulation begin
    //=================================================================
    initial begin
        show_lab_title();
        $value$plusargs("prog_path=%s", prog_path);
        $value$plusargs("rdcycle=%s", rdcycle);
        clk = 0; 
        rst = 1;
        #(`CYCLE) rst = 0;
        $readmemh({prog_path, "/mem0.hex"}, u_dram.MEM0);
        $readmemh({prog_path, "/mem1.hex"}, u_dram.MEM1); 
        $readmemh({prog_path, "/mem2.hex"}, u_dram.MEM2);
        $readmemh({prog_path, "/mem3.hex"}, u_dram.MEM3);
        $readmemh({prog_path, "/mem4.hex"}, u_dram.MEM4);
        $readmemh({prog_path, "/mem5.hex"}, u_dram.MEM5); 

        num = 0;
        gf = $fopen({prog_path, "/golden.hex"}, "r");
        while (!$feof(gf))begin
            code = $fscanf(gf, "%h\n", GOLDEN[num]);
            if (code == 1) begin
                num++;
            end
            else begin
                break;
            end
        end
        $fclose(gf);
        //end signal
        //UART INTERFACE
        $display("\n%s================================[ PROGRAM OUTPUT SCREEN ]=================================%s\n", ANSI_SKY_BLUE, ANSI_RESET);
        wait(`dram_word(`SIM_END) == `SIM_END_CODE);
        $display("\n%s==========================================================================================%s\n", ANSI_SKY_BLUE, ANSI_RESET);
        $display("\nDone\n");
        show_report();
        err = 0;

        for (i = 0; i < num; i++)begin
            if (`dram_word(`TEST_START + i) !== GOLDEN[i]) begin
                $display("DRAM[%h] = %h, expect = %h", (`TEST_START + i)*4 + 'h0c000000, `dram_word(`TEST_START + i), GOLDEN[i]);
                err = err + 1;
            end
            else
            begin
                $display("DRAM[%h] = %h, pass", (`TEST_START + i)*4 + 'h0c000000, `dram_word(`TEST_START + i));
            end
        end
        

        inst_cnt = longint'( {`dram_word(`SIM_RDINST  + 1),
                              `dram_word(`SIM_RDINST     )});
        cyc_cnt  = longint'( {`dram_word(`SIM_RDCYCLE + 1),
                              `dram_word(`SIM_RDCYCLE    )});

        $display("Total instruction count = %0d", inst_cnt);
        $display("Total cycle count       = %0d", cyc_cnt);
        if (inst_cnt != 0) begin
            cpi = real'(cyc_cnt) / real'(inst_cnt);
            $display("CPI = %0.5f", cpi);
        end else begin
            $display("CPI = N/A (inst_cnt = 0)");
        end

        
        t = $realtime;
        $display("CPU stop at simulation time = %0.3f ns", t);
        result(err, num);

        $finish;
    end

    always@(posedge clk, posedge rst)begin
        if(rst) 
            total_cycle <= 64'd0;
        else 
            total_cycle <= total_cycle+64'd1;
    end

    `ifdef SYN
        initial $sdf_annotate("../syn/top_syn.sdf", u_top);
    `endif

    initial begin
        `ifdef FSDB
            $fsdbDumpfile("top.fsdb");
            $fsdbDumpvars(0, top_tb);
        `elsif FSDB_ALL
            $fsdbDumpfile("top.fsdb");
            $fsdbDumpvars("+struct", "+mda", top_tb);
        `endif
        #(`CYCLE*`MAX)
        $display("\n%s==========================================================================================%s\n", ANSI_SKY_BLUE, ANSI_RESET);
        show_report();
        for (i = 0; i < num; i++)begin
            if (`dram_word(`TEST_START + i) !== GOLDEN[i])begin
                $display("DM[%4d] = %h, expect = %h", `TEST_START + i, `dram_word(`TEST_START + i), GOLDEN[i]);
                err = err + 1;
            end
            else begin
                $display("DM[%4d] = %h, pass", `TEST_START + i, `dram_word(`TEST_START + i));
            end
        end
        $display("SIM_END(%5d) = %h, expect = %h", `SIM_END, `dram_word(`SIM_END), `SIM_END_CODE);
        $display("SIMULATION TIMEOUT after %d cycles", `MAX);
        $display("\n");
        show_result(2);
        $finish;
    end
    
    task result;
        input integer err;
        input integer num;
        integer rf;
        begin
            `ifdef SYN
                    rf = $fopen({prog_path, "/result_syn.txt"}, "w");
            `else
                    rf = $fopen({prog_path, "/result_rtl.txt"}, "w");
            `endif
            $fdisplay(rf, "%d,%d", num - err, num);
            if(err == 0) begin
                $display("SIMULATION PASSED!!!!!!!");
                $display("\n");
                show_result(0);
            end
            else begin
                $display("\n");
                show_result(1);
            end
        end
    endtask

endmodule
