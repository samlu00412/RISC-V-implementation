module tag_array_wrapper (
  input         CLK,
  input         CEB,
  input         WEB,
  input  [31:0] BWEB,
  input  [4:0]  A,
  
  input  [31:0] DI,
  output [31:0] DO
);

  TS1N16ADFPCLLLVTA128X64M4SWSHOD_tag_array tag_array_u (
    .CLK        (CLK),
    .A          (A),
    .CEB        (CEB),
    .WEB        (WEB),
    .BWEB       (BWEB),
    .D          (DI),
    .Q          (DO),
    .RTSEL      (2'b01),
    .WTSEL      (2'b01),
    .SLP        (1'd0),
    .DSLP       (1'd0),
    .SD         (1'd0),
    .PUDELAY    ()
  );

endmodule
