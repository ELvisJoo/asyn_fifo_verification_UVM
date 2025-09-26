`timescale 1ns / 1ps

// 读指针同步到写时钟域
module sync_r2w #(parameter ADDRSIZEL = 4)
(
input [ADDRSIZEL : 0] rptr,// 读时钟域的读指针（格雷码）
input wclk,wrst_n,
output reg [ADDRSIZEL : 0] wq2_rptr // 同步到写时钟域的读指针（两级同步后）
 );
 reg [ADDRSIZEL : 0] wq1_rptr;
 
 // 两级同步
 always @(posedge wclk or negedge wrst_n)
 if(!wrst_n)
   {wq2_rptr,wq1_rptr} <= 0;
 else
   {wq2_rptr,wq1_rptr} <= {wq1_rptr,rptr};
  //  wq1_rptr <= rptr;      // 第一级锁存
  //  wq2_rptr <= wq1_rptr;  // 第二级锁存，输出同步后的值
   
endmodule
