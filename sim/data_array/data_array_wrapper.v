//******************************************************************************
// Copyright (c) 2025 Tsai Yu-Chen (Neo)
// Low Power and High Performance (LPHP) Laboratory
// Advisor: Prof. Lih-Yih, Chiou
// All Rights Reserved.
//
// This source code is developed as part of academic coursework at LPHP Lab.
// Unauthorized copying, distribution, modification, or use of this code
// without explicit written permission from the advisor is strictly prohibited.
//
// File        : data_array_wrapper.sv
// Author      : Tsai Yu-Chen (Neo)
// Course      : VLSI System Design
// Advisor     : Prof. Lih-Yih, Chiou
// Created     : 2025/10/05
// Version     : 1.0
// Description : Wrapper module for 128x32 Data Array
//******************************************************************************
module data_array_wrapper (
  input           CLK,
  input           CEB, 
  input           WEB,
  input  [127:0]  BWEB,
  input  [4:0]    A,
  input  [127:0]  DI,
  output [127:0]  DO
);

  TS1N16ADFPCLLLVTA128X64M4SWSHOD_data_array data_array_u1 (
    .CLK        (CLK),
    .A          (A),
    .CEB        (CEB),
    .WEB        (WEB),
    .BWEB       (BWEB[127:64]),
    .D          (DI[127:64]),
    .Q          (DO[127:64]),
    .RTSEL      (2'b01),
    .WTSEL      (2'b01),
    .SLP        (1'd0),
    .DSLP       (1'd0),
    .SD         (1'd0),
    .PUDELAY    ()
  );
  
  TS1N16ADFPCLLLVTA128X64M4SWSHOD_data_array data_array_u2 (
    .CLK        (CLK),
    .A          (A),
    .CEB        (CEB),
    .WEB        (WEB),
    .BWEB       (BWEB[63:0]),
    .D          (DI[63:0]),
    .Q          (DO[63:0]),
    .RTSEL      (2'b01),
    .WTSEL      (2'b01),
    .SLP        (1'd0),
    .DSLP       (1'd0),
    .SD         (1'd0),
    .PUDELAY    ()
  );


endmodule
