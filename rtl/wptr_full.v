`timescale 1ns / 1ps

// 写指针管理与满标志生成
module wptr_full #(parameter ADDRSIZEL = 4)
(
input wclk,wrst_n,winc,
input [ADDRSIZEL : 0] wq2_rptr, // 同步后的读指针（格雷码）
output reg [ADDRSIZEL : 0] wptr, // 写指针(格雷码,多1位)
output [ADDRSIZEL-1 : 0] waddr, // 实际写地址（二进制）
output reg wfull
);

reg [ADDRSIZEL : 0] wbin;// 二进制写指针（用于自增）
wire [ADDRSIZEL : 0] wbnext,wgnext;

// 指针寄存器更新（同步复位）
always@(posedge wclk or negedge wrst_n)
if(!wrst_n)
  {wbin,wptr} <= 0;
else
  {wbin,wptr} <= {wbnext,wgnext};// 输出格雷码指针

// 实际写地址(取指针低ASIZE位)
assign waddr = wbin[ADDRSIZEL-1 : 0]; // 二进制地址用于RAM访问

// 二进制指针自增逻辑
assign wbnext = wbin + (winc & ~wfull); // 写使能有效且未满时自增
assign wgnext = (wbnext>>1) ^ (wbnext); // 二进制转格雷码

// 格雷码比较
wire wfull_val;
assign wfull_val = (wgnext == {~wq2_rptr[ADDRSIZEL : ADDRSIZEL-1],wq2_rptr[ADDRSIZEL-2 : 0]});

// 满标志判断：写指针与同步后的读指针高两位相反，其余位相同
always@(posedge wclk or negedge wrst_n)
if(!wrst_n)
  wfull <= 0;
else
  wfull <= wfull_val;
  
endmodule