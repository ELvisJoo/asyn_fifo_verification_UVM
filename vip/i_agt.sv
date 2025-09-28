`ifndef I_AGT_SV
`define I_AGT_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/my_sequencer.sv"
`include "./vip/my_driver.sv"
`include "./vip/in_monitor.sv"

// i_agent:负责写时钟域的激励和监测
class i_agt extends uvm_agent;
    // 组件实例
    w_driver      wdrv;    // 写驱动
    my_sequencer  wseqr;   // 写序列器
    in_monitor    wmon;    // 输入monitor(写时钟域)
    
    // 配置:是否为Activeagent(有驱动)
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    
    `uvm_component_utils(i_agt)
    
    function new(string name = "i_agt", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // 创建monitor(无论Active/Passive模式都需要)
        wmon = in_monitor::type_id::create("wmon", this);
        
        // Active模式下创建驱动和序列器
        if (is_active == UVM_ACTIVE) begin
            wdrv = w_driver::type_id::create("wdrv", this);
            wseqr = my_sequencer::type_id::create("wseqr", this);
        end
        
        // 从配置数据库获取Active模式配置(可选)
        if (!uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active)) begin
            `uvm_info("I_AGT", "未指定is_active,默认使用UVM_ACTIVE", UVM_LOW)
        end
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Active模式下连接驱动和序列器
        if (is_active == UVM_ACTIVE) begin
            wdrv.seq_item_port.connect(wseqr.seq_item_export);
        end
    endfunction
endclass

`endif

// 1. **i_agt(i_agent)**:
//    - 包含写时钟域的三个核心组件:`w_driver`(写驱动)、`wseqr`(写序列器)和`wmon`(输入monitor)
//    - 通过`is_active`配置是否为Active模式(默认Active):
//      - Active模式(UVM_ACTIVE):创建驱动和序列器,用于生成写激励
//      - Passive模式(UVM_PASSIVE):仅创建monitor,用于观测写操作
//    - 在`connect_phase`中连接写驱动和写序列器的TLM端口

// 2. **o_agt(o_agent)**:
//    - 包含读时钟域的三个核心组件:`r_driver`(读驱动)、`rseqr`(读序列器)和`rmon`(输出monitor)
//    - 同样支持`is_active`配置(默认Active),用于控制是否生成读激励
//    - 在`connect_phase`中连接读驱动和读序列器的TLM端口

// 3. **异步适配**:
//    - 两个agent分别独立工作在写时钟域和读时钟域,符合异步FIFO的特性
//    - 各自的monitor和驱动通过对应的接口modport访问信号,避免跨时钟域冲突
//    - 可通过配置数据库灵活设置agent模式(Active/Passive),适应不同验证场景

// 4. **扩展性**:
//    - 预留了配置接口,可通过`uvm_config_db`动态修改`is_active`参数
//    - 组件命名清晰,便于后续添加功能(如覆盖率收集)

// 这两个agent类将异步FIFO验证环境的读写部分进行了清晰分离,既符合UVM的层次化设计理念,又适配了异步时钟域的特殊需求。