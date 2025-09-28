`ifndef MY_IF_SV
`define MY_IF_SV

interface my_if #(            // 1. 参数定义
    parameter ADDRSIZEL = 4,  // 地址位宽,与RTL保持一致
    parameter DATASIZEL = 8   // 数据位宽,与RTL保持一致
) (
    // 写时钟和复位
    input wclk,
    input wrst_n,
    
    // 读时钟和复位
    input rclk,
    input rrst_n
);
    // 2. 读写信号分组定义
    // 写时钟域信号:wdata、winc、wfull,由写时钟wclk和写复位wrst_n控制
    logic [DATASIZEL-1:0] wdata;  // 写入数据
    logic                 winc;   // 写使能
    logic                 wfull;  // 写满标志
    
    // 读时钟域信号:rdata、rinc、rempty,由读时钟rclk和读复位rrst_n控制
    logic [DATASIZEL-1:0] rdata;  // 读出数据
    logic                 rinc;   // 读使能
    logic                 rempty; // 读空标志
    
    // 3. 时钟块设计(考虑到异步fifo特性,需要做到读写分离)
    // 写时钟域的时钟块(用于驱动和监测)
    clocking wdrv_cb @(posedge wclk);
        default input #1 output #1;
        output wdata, winc;
        input  wfull;
    endclocking
    
    clocking wmon_cb @(posedge wclk);
        default input #1;
        input wdata, winc, wfull;
    endclocking
    
    // 读时钟域的时钟块(用于驱动和监测)
    clocking rdrv_cb @(posedge rclk);
        default input #1 output #1;
        output rinc;
        input  rdata, rempty;
    endclocking
    
    clocking rmon_cb @(posedge rclk);
        default input #1;
        input rinc, rdata, rempty;
    endclocking
    
    // 4. modport定义,区分不同角色的访问方式
    modport WDRIVER (clocking wdrv_cb, input wclk, wrst_n);
    modport WMONITOR(clocking wmon_cb, input wclk, wrst_n);
    modport RDRIVER (clocking rdrv_cb, input rclk, rrst_n);
    modport RMONITOR(clocking rmon_cb, input rclk, rrst_n);
    
    // 异步FIFO的复位信号监测
    property reset_check;
        @(negedge wrst_n) disable iff (!wrst_n)
        (wfull == 1'b0);  // 写复位时,写满标志应清零
    endproperty
    
    property reset_check2;
        @(negedge rrst_n) disable iff (!rrst_n)
        (rempty == 1'b1);  // 读复位时,读空标志应置位
    endproperty
    
    // 5. 断言:检查复位时的信号状态
    RESET_CHECK_ASSERT: assert property(reset_check)
        else `uvm_error("RST_ERR", "写复位时wfull未清零")
    
    RESET_CHECK2_ASSERT: assert property(reset_check2)
        else `uvm_error("RST_ERR", "读复位时rempty未置位")

endinterface

`endif


// 1. 参数化定义:包含了与 RTL 一致的ADDRSIZEL和DATASIZEL参数,确保接口可以灵活适配不同配置的 FIFO

// 2. 信号分组:
// 写时钟域:wdata、winc、wfull,由写时钟wclk和写复位wrst_n控制
// 读时钟域:rdata、rinc、rempty,由读时钟rclk和读复位rrst_n控制

// 3. 时钟块设计:
// 为写时钟域和读时钟域分别创建了驱动时钟块 (wdrv_cb、rdrv_cb) 和监测时钟块 (wmon_cb、rmon_cb)
// 这样可以确保在异步时钟域下正确地进行信号驱动和采样

// 4. Modport 定义:明确区分了写驱动、写监测、读驱动和读监测四种角色的接口访问方式,提高了验证环境的封装性

// 5. 基本断言:添加了复位时的信号状态检查,确保复位行为符合预期

// 参考异步 FIFO 的跨时钟域特性,能够支持后续 UVM 验证环境的搭建,实现读写分离的 driver 和 monitor 。