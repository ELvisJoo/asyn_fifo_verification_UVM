`ifndef MY_ENV_SV
`define MY_ENV_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/i_agt.sv"
`include "./vip/o_agt.sv"
`include "./vip/my_model.sv"
`include "./vip/my_scoreboard.sv"
`include "./vip/fifo_rst_mon.sv"
`include "./vip/fifo_chk_rst.sv"

class my_env extends uvm_env;
    // 组件实例
    i_agt           i_agent;      // i_agent(写时钟域)
    o_agt           o_agent;      // o_agent(读时钟域)
    my_model        model;        // reference_model
    my_scoreboard   scb;          // scoreboard
    fifo_rst_mon    rst_mon;      // 复位监测器
    fifo_chk_rst    rst_chk;      // 复位检查器
    
    `uvm_component_utils(my_env)
    
    function new(string name = "my_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // 创建各组件
        i_agent  = i_agt::type_id::create("i_agent", this);
        o_agent  = o_agt::type_id::create("o_agent", this);
        model    = my_model#(4,8)::type_id::create("model", this);
        scb      = my_scoreboard::type_id::create("scb", this);
        rst_mon  = fifo_rst_mon::type_id::create("rst_mon", this);
        rst_chk  = fifo_chk_rst::type_id::create("rst_chk", this);
        
        // 配置agent模式(默认Active模式,可通过配置数据库修改)
        uvm_config_db#(uvm_active_passive_enum)::set(this, "i_agent", "is_active", UVM_ACTIVE);
        uvm_config_db#(uvm_active_passive_enum)::set(this, "o_agent", "is_active", UVM_ACTIVE);
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // 1. 连接i_agent到reference_model(写操作传递给模型)
        i_agent.wmon.ap.connect(model.w_port);
        
        // 2. 连接reference_model到scoreboard(预期结果传递给scoreboard)
        model.r_port.connect(scb.exp_port);
        
        // 3. 连接o_agent到scoreboard(实际结果传递给scoreboard)
        o_agent.rmon.ap.connect(scb.act_port);
        
        // 4. 连接fifo_rst_mon到fifo_chk_rst
        rst_mon.wrst_ap.connect(rst_chk.wrst_imp);
        rst_mon.rrst_ap.connect(rst_chk.rrst_imp);
        
        // 5. fifo_chk_rst到scoreboard的连接方式
        // 创建专用分析端口连接复位状态更新函数
        rst_chk.wrst_ap.connect(scb.wrst_imp);
        rst_chk.rrst_ap.connect(scb.rrst_imp);
    endfunction
    
    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        // 打印环境结构
        `uvm_info("ENV_STRUCTURE", $sformatf("环境结构:\n%s", this.sprint()), UVM_LOW)
    endfunction

endclass
`endif

// ### 关键连接说明:

// 1. **数据通路**:

// * 输入代理(i_agent)的监测器端口(wmon.ap)-------→ 参考模型(my_model)的 w_port

// * 参考模型(my_model)的 r_port ----------------→ 计分板(my_scoreboard)的 exp_port(预期数据)

// * 输出代理(o_agent)的监测器端口(rmon.ap)-------→ 计分板(my_scoreboard)的 act_port(实际数据)

// 1. **复位通路**:

// * 复位监测器(fifo_rst_mon)的 wrst_ap -------→ 复位检查器(fifo_chk_rst)的 wrst_imp

// * 复位监测器(fifo_rst_mon)的 rrst_ap -------→ 复位检查器(fifo_chk_rst)的 rrst_imp

// * 复位检查器(fifo_rst_mon)的 wrst_ap -------→ 计分板(my_scoreboard)的 update_wrst_state(写复位状态更新)

// * 复位检查器(fifo_rst_mon)的 rrst_ap -------→ 计分板(my_scoreboard)的 update_rrst_state(读复位状态更新)


// 这种结构实现了:

// * 预期数据从输入代理(i_agent)到参考模型(my_model)再到计分板(my_scoreboard)的通路

// * 实际数据从输出代理(o_agent)直接到计分板(my_scoreboard)的通路

// * 复位信号从监测器(fifo_rst_mon)到检查器(fifo_chk_rst)再到计分板(my_scoreboard)的状态通知通路

