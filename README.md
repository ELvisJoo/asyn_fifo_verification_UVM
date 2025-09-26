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


### 异步 FIFO RTL 代码解析与注释

异步 FIFO（异步先进先出）是跨时钟域数据传输的关键模块，主要由存储单元、读写指针、空满判断及跨时钟域同步模块组成。以下是各核心模块的解析：

#### 1. 顶层模块 `asyn_fifo.v`



```
// 异步FIFO顶层模块：连接读写时钟域的子模块

module asyn\_fifo #(

&#x20;   parameter DSIZE = 8,      // 数据位宽

&#x20;   parameter ASIZE = 4       // 地址位宽（深度=2^ASIZE）

)(

&#x20;   // 写时钟域信号

&#x20;   input  wclk,             // 写时钟

&#x20;   input  wrst\_n,           // 写复位（低有效）

&#x20;   input  winc,             // 写使能

&#x20;   input  \[DSIZE-1:0] wdata,// 写入数据

&#x20;   output wfull,            // 写满标志

&#x20;  &#x20;

&#x20;   // 读时钟域信号

&#x20;   input  rclk,             // 读时钟

&#x20;   input  rrst\_n,           // 读复位（低有效）

&#x20;   input  rinc,             // 读使能

&#x20;   output \[DSIZE-1:0] rdata,// 读出数据

&#x20;   output rempty            // 读空标志

);

// 内部信号：读写指针及同步后指针

wire \[ASIZE-1:0] waddr, raddr;          // 实际地址（二进制）

wire \[ASIZE:0]   wptr, rptr;            // 读写指针（格雷码，多1位用于空满判断）

wire \[ASIZE:0]   wq2\_rptr, rq2\_wptr;    // 跨时钟域同步后的指针

// 1. 存储单元：双端口RAM，读写时钟独立

fifomem #(DSIZE, ASIZE) fifomem (

&#x20;   .wdata  (wdata),

&#x20;   .waddr  (waddr),

&#x20;   .wclken (winc && !wfull),  // 写使能有效且未满

&#x20;   .wclk   (wclk),

&#x20;   .raddr  (raddr),

&#x20;   .rdata  (rdata)

);

// 2. 写指针与满标志生成

wptr\_full #(ASIZE) wptr\_full (

&#x20;   .wclk    (wclk),

&#x20;   .wrst\_n  (wrst\_n),

&#x20;   .winc    (winc),

&#x20;   .wq2\_rptr(wq2\_rptr),       // 同步后的读指针

&#x20;   .waddr   (waddr),          // 输出实际写地址

&#x20;   .wptr    (wptr),           // 输出写指针（格雷码）

&#x20;   .wfull   (wfull)           // 写满标志

);

// 3. 读指针与空标志生成

rptr\_empty #(ASIZE) rptr\_empty (

&#x20;   .rclk    (rclk),

&#x20;   .rrst\_n  (rrst\_n),

&#x20;   .rinc    (rinc),

&#x20;   .rq2\_wptr(rq2\_wptr),       // 同步后的写指针

&#x20;   .raddr   (raddr),          // 输出实际读地址

&#x20;   .rptr    (rptr),           // 输出读指针（格雷码）

&#x20;   .rempty  (rempty)          // 读空标志

);

// 4. 读指针同步到写时钟域（两级寄存器同步，减少亚稳态）

sync\_r2w #(ASIZE) sync\_r2w (

&#x20;   .wclk    (wclk),

&#x20;   .wrst\_n  (wrst\_n),

&#x20;   .rptr    (rptr),           // 原始读指针

&#x20;   .wq2\_rptr(wq2\_rptr)        // 同步到写时钟域的读指针

);

// 5. 写指针同步到读时钟域

sync\_w2r #(ASIZE) sync\_w2r (

&#x20;   .rclk    (rclk),

&#x20;   .rrst\_n  (rrst\_n),

&#x20;   .wptr    (wptr),           // 原始写指针

&#x20;   .rq2\_wptr(rq2\_wptr)        // 同步到读时钟域的写指针

);

endmodule
```

#### 2. 存储单元 `fifomem.v`



```
// FIFO存储单元：双端口RAM，支持异步读写

module fifomem #(

&#x20;   parameter DSIZE = 8,

&#x20;   parameter ASIZE = 4

)(

&#x20;   input  \[DSIZE-1:0] wdata,  // 写入数据

&#x20;   input  \[ASIZE-1:0] waddr,  // 写地址

&#x20;   input              wclken, // 写使能（含满标志判断）

&#x20;   input              wclk,   // 写时钟

&#x20;   input  \[ASIZE-1:0] raddr,  // 读地址

&#x20;   output \[DSIZE-1:0] rdata   // 读出数据

);

// 定义RAM数组（深度=2^ASIZE）

reg \[DSIZE-1:0] mem \[0:(1<\<ASIZE)-1];

// 写操作：同步到写时钟

always @(posedge wclk) begin

&#x20;   if (wclken) begin

&#x20;       mem\[waddr] <= wdata;  // 写使能有效时写入数据

&#x20;   end

end

// 读操作：异步读（或同步到读时钟，根据需求调整）

assign rdata = mem\[raddr];  // 组合逻辑输出，读地址变化立即反映

endmodule
```

#### 3. 写指针与满标志 `wptr_full.v`



```
// 写指针管理与满标志生成

module wptr\_full #(

&#x20;   parameter ASIZE = 4

)(

&#x20;   input                 wclk,

&#x20;   input                 wrst\_n,

&#x20;   input                 winc,         // 写请求

&#x20;   input  \[ASIZE:0]      wq2\_rptr,    // 同步后的读指针（格雷码）

&#x20;   output reg \[ASIZE-1:0] waddr,       // 实际写地址（二进制）

&#x20;   output reg \[ASIZE:0]  wptr,         // 写指针（格雷码，多1位）

&#x20;   output reg            wfull         // 满标志

);

reg \[ASIZE:0] wbin;  // 二进制写指针（用于自增）

wire \[ASIZE:0] wgray\_next, wbin\_next;

// 1. 二进制指针自增逻辑

assign wbin\_next = wbin + (winc & \~wfull);  // 写使能有效且未满时自增

assign wgray\_next = (wbin\_next >> 1) ^ wbin\_next;  // 二进制转格雷码

// 2. 指针寄存器更新（同步复位）

always @(posedge wclk or negedge wrst\_n) begin

&#x20;   if (!wrst\_n) begin

&#x20;       wbin <= 0;

&#x20;       wptr <= 0;

&#x20;   end else begin

&#x20;       wbin <= wbin\_next;

&#x20;       wptr <= wgray\_next;  // 输出格雷码指针

&#x20;   end

end

// 3. 实际写地址（取指针低ASIZE位）

always @(\*) begin

&#x20;   waddr = wbin\[ASIZE-1:0];  // 二进制地址用于RAM访问

end

// 4. 满标志判断：写指针与同步后的读指针高两位相反，其余位相同

always @(posedge wclk or negedge wrst\_n) begin

&#x20;   if (!wrst\_n) begin

&#x20;       wfull <= 1'b0;

&#x20;   end else begin

&#x20;       // 格雷码比较：(wgray\_next == {\~wq2\_rptr\[ASIZE:ASIZE-1], wq2\_rptr\[ASIZE-2:0]})

&#x20;       wfull <= (wgray\_next == {\~wq2\_rptr\[ASIZE], \~wq2\_rptr\[ASIZE-1], wq2\_rptr\[ASIZE-2:0]});

&#x20;   end

end

endmodule
```

#### 4. 读指针与空标志 `rptr_empty.v`



```
// 读指针管理与空标志生成

module rptr\_empty #(

&#x20;   parameter ASIZE = 4

)(

&#x20;   input                 rclk,

&#x20;   input                 rrst\_n,

&#x20;   input                 rinc,         // 读请求

&#x20;   input  \[ASIZE:0]      rq2\_wptr,    // 同步后的写指针（格雷码）

&#x20;   output reg \[ASIZE-1:0] raddr,       // 实际读地址（二进制）

&#x20;   output reg \[ASIZE:0]  rptr,         // 读指针（格雷码，多1位）

&#x20;   output reg            rempty        // 空标志

);

reg \[ASIZE:0] rbin;  // 二进制读指针

wire \[ASIZE:0] rgray\_next, rbin\_next;

// 1. 二进制指针自增逻辑

assign rbin\_next = rbin + (rinc & \~rempty);  // 读使能有效且未空时自增

assign rgray\_next = (rbin\_next >> 1) ^ rbin\_next;  // 二进制转格雷码

// 2. 指针寄存器更新

always @(posedge rclk or negedge rrst\_n) begin

&#x20;   if (!rrst\_n) begin

&#x20;       rbin <= 0;

&#x20;       rptr <= 0;

&#x20;   end else begin

&#x20;       rbin <= rbin\_next;

&#x20;       rptr <= rgray\_next;

&#x20;   end

end

// 3. 实际读地址

always @(\*) begin

&#x20;   raddr = rbin\[ASIZE-1:0];

end

// 4. 空标志判断：读指针与同步后的写指针完全相等

always @(posedge rclk or negedge rrst\_n) begin

&#x20;   if (!rrst\_n) begin

&#x20;       rempty <= 1'b1;  // 复位时为空

&#x20;   end else begin

&#x20;       rempty <= (rgray\_next == rq2\_wptr);  // 格雷码相等则为空

&#x20;   end

end

endmodule
```

#### 5. 跨时钟域同步模块 `sync_r2w.v` 和 `sync_w2r.v`



```
// 读指针同步到写时钟域（两级D触发器同步，降低亚稳态概率）

module sync\_r2w #(

&#x20;   parameter ASIZE = 4

)(

&#x20;   input              wclk,

&#x20;   input              wrst\_n,

&#x20;   input  \[ASIZE:0]   rptr,       // 读时钟域的读指针（格雷码）

&#x20;   output reg \[ASIZE:0] wq2\_rptr   // 同步到写时钟域的读指针（两级同步后）

);

reg \[ASIZE:0] wq1\_rptr;  // 一级同步寄存器

// 两级同步：第一级打拍

always @(posedge wclk or negedge wrst\_n) begin

&#x20;   if (!wrst\_n) begin

&#x20;       wq1\_rptr <= 0;

&#x20;       wq2\_rptr <= 0;

&#x20;   end else begin

&#x20;       wq1\_rptr <= rptr;      // 第一级锁存

&#x20;       wq2\_rptr <= wq1\_rptr;  // 第二级锁存，输出同步后的值

&#x20;   end

end

endmodule

// 写指针同步到读时钟域（结构与sync\_r2w完全相同）

module sync\_w2r #(

&#x20;   parameter ASIZE = 4

)(

&#x20;   input              rclk,

&#x20;   input              rrst\_n,

&#x20;   input  \[ASIZE:0]   wptr,       // 写时钟域的写指针（格雷码）

&#x20;   output reg \[ASIZE:0] rq2\_wptr   // 同步到读时钟域的写指针

);

reg \[ASIZE:0] rq1\_wptr;

always @(posedge rclk or negedge rrst\_n) begin

&#x20;   if (!rrst\_n) begin

&#x20;       rq1\_wptr <= 0;

&#x20;       rq2\_wptr <= 0;

&#x20;   end else begin

&#x20;       rq1\_wptr <= wptr;

&#x20;       rq2\_wptr <= rq1\_wptr;

&#x20;   end

end

endmodule
```

### 二、UVM 验证环境原理框图

该项目的 UVM 验证环境采用标准的分层结构，主要包含以下组件，框图如下：


```
+------------------------------------------------------------------------------------------------+

|                                       顶层测试 (my\_test)                                       |

+------------------------------------------------------------------------------------------------+

                                              |

+------------------------------------------------------------------------------------------------+

|                                       验证环境 (my\_env)                                        |

+------------------------------------------------------------------------------------------------+

|  +----------------+       +----------------+       +----------------+       +----------------+  |

|  |   输入代理     |       |   输出代理      |       |   参考模型    |       |   计分板          |  |

|  |  (i\_agt)     |       |  (o\_agt)       |      |  (my\_model)  |       |(my\_scoreboard)  |  |

|  +----------------+       +----------------+       +----------------+       +----------------+  |

|  | +------------+ |       | +------------+ |               |                       |            |

|  | | 序列器     | |        | | 监视器     | |               |                       |            |

|  | |(sequencer) |<--------->|(monitor)   |<--------------+                         |            |

|  | +------------+ |       | +------------+ |               |                       |            |

|  | | 驱动       | |       |                |               |                       |            |

|  | |(driver)    | |       |                |               |                       |            |

|  | +------------+ |       |                |               |                       |            |

|  +----------------+       +----------------+               |                       |            |

|         |                         |                        |                       |            |

+--------------------------------------------------------------------------------------------------+

|         |                         |                        |                       |            |

|         v                         v                        v                       v            |

|  +----------------+       +----------------+       +----------------+       +----------------+  |

|  |   接口         |       |   接口         |        |  预期结果      |       |  比对结果      |   |

|  |(my\_if/wclk)   |       |(my\_if/rclk)    |      |                |       | (Pass/Fail)   |   |

|  +----------------+       +----------------+       +----------------+       +----------------+  |

|                 |                                            |                                  |

+------------------------------------------------------------------------------------------------+

                  |                                            |

                  v                                            |

+------------------------------------------------------------------------------------------------+

|                               DUT (asyn\_fifo)                                                  |

|       (接收写时钟域激励，输出到读时钟域，验证跨时钟域数据传输正确性)                                 |

+------------------------------------------------------------------------------------------------+

                      |                                            |

                      v                                            v

+------------------------------------------------------------------------------------------------+

|         输入数据/控制信号                         输出数据/状态信号 (被监视器采集)                 |

+------------------------------------------------------------------------------------------------+
```

#### 各组件功能说明：



1.  **测试用例（my\_test）**：配置验证环境，启动测试序列（如随机读写、边界测试等）。

2.  **环境（my\_env）**：集成所有验证组件，协调各模块工作。

3.  **输入代理（i\_agt）**：

*   **序列器（sequencer）**：生成激励序列（如随机写数据、写使能）。

*   **驱动（driver）**：将序列转换为物理信号（如 wdata、winc），驱动到 DUT 的写接口。

1.  **输出代理（o\_agt）**：

*   **监视器（monitor）**：采集 DUT 读接口的输出信号（如 rdata、rempty），转换为事务（transaction）。

1.  **参考模型（my\_model）**：模拟 DUT 的理想行为（如正确的跨满判断、数据缓存），生成预期结果。

2.  **计分分板（my\_scoreboard）**：比对监视器采集的实际结果与参考模型的预期结果，判断 DUT 功能是否正确。

3.  **接口（my\_if）**：连接验证环境与 DUT，包含读写时钟域的所有信号（如 wclk、rclk、wdata、rdata 等）。

通过以上结构，验证环境可自动生成激励、监控 DUT 行为、比对结果，实现对异步 FIFO 的全面功能验证。


