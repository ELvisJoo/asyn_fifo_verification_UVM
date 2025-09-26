`timescale 1ns / 1ps

// 写指针同步到读时钟域,结构与sync_r2w完全相同
module sync_w2r #(parameter ADDRSIZEL = 4)
(
input [ADDRSIZEL : 0] wptr,// 写时钟域的写指针(格雷码)
output reg [ADDRSIZEL : 0] rq2_wptr, // 同步到读时钟域的写指针（两级同步后）
input rclk,rrst_n
);

reg [ADDRSIZEL : 0] rq1_wptr;

// 两级同步
always@(posedge rclk or negedge rrst_n)
if(!rrst_n)
  {rq2_wptr,rq1_wptr} <= 0;
else
  {rq2_wptr,rq1_wptr} <= {rq1_wptr,wptr};
  //  rq1_wptr <= wptr;    // 第一级锁存
  //  rq2_wptr <= rq1_wptr;// 第二级锁存，输出同步后的值

endmodule