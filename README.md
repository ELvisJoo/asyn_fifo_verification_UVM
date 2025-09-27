# 异步 FIFO 的 UVM 验证

这是一个基于 UVM（Universal Verification Methodology，通用验证方法学）的异步 FIFO（First In First Out，先进先出）验证项目。以下是对该项目的具体介绍：

### 项目核心目标

该项目主要用于验证异步 FIFO 的功能正确性。异步 FIFO 是一种在不同时钟域下进行数据传输的存储结构，验证的核心在于确保数据在跨时钟域传输时的准确性、完整性，以及空满状态判断等关键功能是否符合设计要求。  

### 主要组成部分

1. **设计文件（RTL）**：

   从`filelist.f`可知，包含异步 FIFO 的核心设计模块，如：

*   `asyn_fifo.v`：异步 FIFO 顶层模块

*   `fifomem.v`：FIFO 存储单元模块

*   `rptr_empty.v`：读指针及空状态判断模块

*   `sync_r2w.v`、`sync_w2r.v`：读写指针跨时钟域同步模块

*   `wptr_full.v`：写指针及满状态判断模块

1. **验证环境文件（UVM）**：

   基于 UVM 框架搭建的验证组件，包括：

*   `my_if.sv`：接口文件，用于连接验证环境与 DUT（设计 - under-test）

*   `my_transaction.sv`：定义激励和响应的数据 transaction 格式

*   `my_driver.sv`：驱动模块，将 transaction 转换为物理信号激励

*   `my_sequencer.sv`：序列器，负责产生和管理测试序列

*   `in_monitor.sv`、`out_monitor.sv`：输入 / 输出监视器，用于采集总线上的信号并转换为 transaction

*   `i_agt.sv`、`o_agt.sv`：输入 / 输出代理（agent），包含驱动、监视器和序列器的集成

*   `my_model.sv`：参考模型，用于模拟 DUT 的理想行为，生成预期结果

*   `my_scoreboard.sv`：计分板，对比监视器采集的实际结果与参考模型的预期结果，判断功能是否正确

*   `my_env.sv`：验证环境顶层，集成所有验证组件（代理、参考模型、计分板等）

*   `base_test.sv`：基础测试用例，定义验证环境的基本配置

*   `my_case0.sv`、`my_case1.sv`：具体测试用例，继承自基础测试，可配置不同场景进行验证

*   `fifo_rst_mon.sv`、`fifo_chk_rst.sv`：可能与复位监控和检查相关的模块

1.  **脚本文件**：

*   `Makefile`：提供编译、仿真、覆盖率分析等命令：


    *   `COMPILE`：使用 VCS 编译器编译设计和验证代码，支持 UVM 库、FSDB 波形记录、覆盖率收集（翻转、条件、状态机）
    
    *   `SIMULATION`：运行仿真，生成覆盖率数据
    
    *   `URG`：使用 URG 工具生成覆盖率报告
    
    *   `clean`：清理编译和仿真生成的中间文件

### 工作流程

1.  通过`make COMPILE`编译整个项目（设计文件 + UVM 验证环境），生成可执行仿真文件`simv`。

2.  执行`make SIMULATION`运行仿真，验证指定测试用例（如`my_case0`），同时收集覆盖率数据。

3.  用`make URG`生成覆盖率报告，分析验证的充分性。

4.  可通过`make clean`清理中间文件，重新编译或仿真。


### 一、异步 FIFO RTL 代码解析与注释

异步 FIFO（异步先进先出）是跨时钟域数据传输的关键模块，主要由存储单元、读写指针、空满判断及跨时钟域同步模块组成。以下是各核心模块的解析：

#### 1. 顶层模块 `asyn_fifo.v`



```
// 异步FIFO顶层模块：连接读写时钟域的子模块

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

```

#### 2. 存储单元 `fifomem.v`



```
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

```

#### 3. 写指针与满标志 `wptr_full.v`



```
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
```

#### 4. 读指针与空标志 `rptr_empty.v`



```
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
```

#### 5. 跨时钟域同步模块 `sync_r2w.v` 和 `sync_w2r.v`



```
// 读指针同步到写时钟域（两级D触发器同步，降低亚稳态概率）

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

```


### 二、 testcase 代码解析与注释


为确保FIFO验证的全面性，需要覆盖功能、边界、异常、性能等多维度场景。以下是完善的FIFO验证测试用例（Testcase）清单，按优先级排序：


## **一、基础功能验证（必选）**
1. **正常读写测试**  
   - 连续写入N个数据，再连续读出，验证输入输出数据一致性。  
   - 交替进行读写操作（写1个读1个），验证FIFO数据流转正确性。  

2. **空状态验证**  
   - FIFO空时，执行读操作，验证：  
     - 空信号（`empty`）是否保持为1。  
     - 读数据（`rd_data`）是否为无效值（或符合RTL定义的默认值）。  
     - 读操作不影响FIFO状态（避免下溢）。  

3. **满状态验证**  
   - FIFO写满后，执行写操作，验证：  
     - 满信号（`full`）是否保持为1。  
     - 新数据不被写入（避免溢出）。  
     - FIFO内已有数据不变。  


## **二、边界条件验证（必选）**
1. **深度边界测试**  
   - 写入FIFO深度-1个数据，验证未满（`full=0`）。  
   - 写入FIFO深度个数据，验证已满（`full=1`）。  
   - 从满状态读出1个数据，验证非满（`full=0`且`empty=0`）。  
   - 从空状态写入1个数据，验证非空（`empty=0`且`full=0`）。  

2. **数据宽度边界**  
   - 写入最小数据（如8'h00）和最大数据（如8'hFF），验证读出值一致。  
   - 写入特殊值（如8'hAA、8'h55），验证数据完整性。  


## **三、异常场景验证（必选）**
1. **复位相关测试**  
   - 复位期间（`rst_n=0`）：验证`full=0`、`empty=1`、`rd_data`清零（或符合RTL定义）。  
   - 复位释放后：验证FIFO状态正确初始化（空状态），可正常读写。  
   - 读写过程中插入复位：验证复位后FIFO清空，重新操作无残留数据。  

2. **无效操作测试**  
   - 同时使能读写（`wr_en=1`且`rd_en=1`）：  
     - 若RTL支持“同时读写”（满时写无效/空时读无效），验证逻辑正确性。  
     - 若RTL不支持，验证无异常行为（如数据损坏、状态错误）。  
   - 无读写操作（`wr_en=0`且`rd_en=0`）：验证`full`/`empty`状态保持不变。  


## **四、性能与时序验证（可选，根据需求）**
1. **最大吞吐量测试**  
   - 连续满速写入（`wr_en=1`且`full=0`时持续写），直到FIFO满，验证写入数据量等于FIFO深度。  
   - 连续满速读出（`rd_en=1`且`empty=0`时持续读），验证读出数据量等于写入量。  

2. **读写延迟测试**  
   - 写操作后，验证数据何时可被读出（如写后1个周期即可读）。  
   - 读操作后，验证`empty`信号何时更新（如读最后1个数据后，下周期`empty=1`）。  


## **五、特殊功能验证（按需添加）**
根据FIFO的具体特性（如同步/异步、带Almost Full/Empty、突发模式等）补充：  
1. **同步/异步FIFO特有测试**  
   - 异步FIFO：跨时钟域读写，验证数据在不同时钟频率下的一致性（需确保跨时钟域处理正确）。  
2. **Almost信号验证**  
   - 若FIFO有`almost_full`（差1个满）或`almost_empty`（差1个空）信号，验证其触发时机是否准确。  
3. **突发读写测试**  
   - 连续写入N个数据（突发长度N < 深度），再连续读出，验证突发操作的完整性。  


## **六、测试用例实现**
- 基于`base_test`派生具体测试类（如`normal_rw_test`、`reset_test`），每个测试类专注于一类场景。  
- 通过序列（`sequence`）控制激励生成：例如，`reset_sequence`在读写过程中插入复位，`boundary_sequence`专门触发满/空边界。  
- 结合断言（SVA）增强验证：例如，断言“满时写操作不改变FIFO数据”“空时读操作不产生有效数据”等。  

通过覆盖以上场景，可基本确保FIFO的功能正确性、边界鲁棒性和异常处理能力，满足工业级验证的完整性要求。


