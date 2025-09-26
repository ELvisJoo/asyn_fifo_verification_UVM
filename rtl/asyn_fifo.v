`timescale 1ns / 1ps

module asyn_fifo #(
    parameter ADDRSIZEL = 4,   // 地址位宽 DEPTH = 1<<ADDRSIZEl; 
    parameter DATASIZEL = 8)   // 数据位宽
(
    // 写时钟域信号
    input  wclk,               // 写时钟
    input  wrst_n,             // 写复位（低有效）
    input  winc,               // 写使能
    input  [DATASIZEL-1 : 0] wdata,// 写入数据
    output wfull,              // 写满标志

     // 读时钟域信号
    input  rclk,               // 读时钟
    input  rrst_n,             // 读复位（低有效）
    input  rinc,               // 读使能
    output [DATASIZEL-1 : 0] rdata,// 读出数据
    output rempty              // 读空标志

    );
// 内部信号：读写指针及同步后指针
wire [ADDRSIZEL - 1 : 0] waddr,raddr;// 实际地址(二进制)
wire [ADDRSIZEL : 0] rptr,wptr;// 读写指针(格雷码,多1位用于空满判断)
wire [ADDRSIZEL : 0] wq2_rptr,rq2_wptr;// 跨时钟域同步后的指针

// 1. 存储单元:双端口RAM,读写时钟独立
fifomem fifomem11(
.waddr(waddr),
.raddr(raddr),
.wdata(wdata),
.wclk(wclk),
.wclken(winc),
.wfull(wfull),
.rdata(rdata)
);

// 2. 读指针同步到写时钟域（两级寄存器同步，减少亚稳态）
sync_r2w sync_r2w11(
.rptr(rptr),
.wclk(wclk),
.wrst_n(wrst_n),
.wq2_rptr(wq2_rptr)
);

// 3. 写指针同步到读时钟域
sync_w2r sync_w2r11(
.wptr(wptr),
.rq2_wptr(rq2_wptr),
.rclk(rclk),
.rrst_n(rrst_n)
);

// 4. 读指针与空标志生成
rptr_empty  rpte_empty11(
.rrst_n(rrst_n),
.rclk(rclk),
.rinc(rinc),
.rq2_wptr(rq2_wptr),
.raddr(raddr),
.rptr(rptr),
.rempty(rempty)
);   

// 5. 写指针与满标志生成
wptr_full wptr_full11(
.wclk(wclk),
.wrst_n(wrst_n),
.winc(winc),
.wq2_rptr(wq2_rptr),
.wptr(wptr),
.waddr(waddr),
.wfull(wfull)
);
endmodule
