`timescale 1ns / 1ps

// FIFO存储单元:双端口RAM,支持异步读写
module fifomem  #( 
  parameter DATASIZEl = 8,  //number of mem datasize bits
  parameter ADDRSIZEl = 4)  //number of mem address bits
(
  input  [ADDRSIZEl-1 : 0] waddr,
  input  [DATASIZEl-1 : 0] wdata,
  input  wclken,
  input  wfull,
  input  wclk,
  input  [ADDRSIZEl-1 : 0] raddr,
  output [DATASIZEl-1 : 0] rdata

 );
 
 //RTL verilog memory model
 localparam DEPTH = 1<<ADDRSIZEl;
 reg [DATASIZEl-1 : 0] mem[DEPTH-1 : 0];
 
//READ
 assign rdata = mem[raddr];

//WRITE
 always@(posedge wclk)
   if(wclken && ~wfull) mem[waddr] = wdata;
    
endmodule
