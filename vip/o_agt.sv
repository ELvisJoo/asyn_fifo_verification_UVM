`ifndef O_AGT_SV
`define O_AGT_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/my_sequencer.sv"
`include "./vip/my_driver.sv"
`include "./vip/out_monitor.sv"

// o_agent:负责读时钟域的激励和监测
class o_agt extends uvm_agent;
    // 组件实例
    r_driver      rdrv;    // 读驱动
    my_sequencer  rseqr;   // 读序列器
    out_monitor   rmon;    // out_monitor(读时钟域)
    
    // 配置:是否为Active agent(有驱动)
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    
    `uvm_component_utils(o_agt)
    
    function new(string name = "o_agt", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // 创建monitor(无论Active/Passive模式都需要)
        rmon = out_monitor::type_id::create("rmon", this);
        
        // Active模式下创建驱动和序列器
        if (is_active == UVM_ACTIVE) begin
            rdrv = r_driver::type_id::create("rdrv", this);
            rseqr = my_sequencer::type_id::create("rseqr", this);
        end
        
        // 从配置数据库获取Active模式配置(可选)
        if (!uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active)) begin
            `uvm_info("O_AGT", "未指定is_active,默认使用UVM_ACTIVE", UVM_LOW)
        end
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Active模式下连接驱动和序列器
        if (is_active == UVM_ACTIVE) begin
            rdrv.seq_item_port.connect(rseqr.seq_item_export);
        end
    endfunction
endclass

`endif
