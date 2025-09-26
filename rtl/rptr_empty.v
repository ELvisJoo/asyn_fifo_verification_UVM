`timescale 1ns / 1ps

// 读指针管理与空标志生成
module rptr_empty #(parameter ADDRSIZEL = 4)
(
input rrst_n,rclk,rinc,
input [ADDRSIZEL : 0] rq2_wptr,
output [ADDRSIZEL-1 : 0] raddr,
output reg [ADDRSIZEL : 0] rptr,
output reg rempty
);

reg [ADDRSIZEL : 0] rbin;// 二进制读指针
wire [ADDRSIZEL : 0] rbnext,rgnext;
wire rempty_val;

// 指针寄存器更新
always@(posedge rclk or negedge rrst_n)
if(!rrst_n)
  {rptr,rbin} <= 0;
else
  {rptr,rbin} <= {rgnext,rbnext};

//  实际读地址
assign raddr = rbin[ADDRSIZEL-1 : 0];

// 二进制指针自增逻辑
assign rbnext = rbin + (rinc & ~rempty);// 读使能有效且未空时自增  
assign rgnext = rbnext>>1 ^ rbnext;// 二进制转格雷码

// 空标志判断:读指针与同步后的写指针完全相等 assign rempty = (rq2_wptr == rptr) ? 1 : 0;  
assign rempty_val = (rgnext == rq2_wptr) ? 1 : 0;
always@(posedge rclk or negedge rrst_n)
  if(!rrst_n) 
    rempty <= 1;//复位时为空
  else
    rempty <= rempty_val;//格雷码相等则为空
endmodule