`ifndef OUT_MONITOR_SV
`define OUT_MONITOR_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/my_transaction.sv"
`include "./vip/my_if.sv"

// 输出monitor:监测读时钟域的输出信号
class out_monitor extends uvm_monitor;
    uvm_analysis_port #(my_transaction) ap;  // 分析端口,发送监测到的事务
    
    virtual my_if.RMONITOR vif;  // 虚拟接口,读监测视角
    
    `uvm_component_utils(out_monitor)
    
    function new(string name = "out_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);  // 初始化分析端口
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 从配置数据库获取接口
        if(!uvm_config_db#(virtual my_if.RMONITOR)::get(this, "", "r_if", vif)) begin
            `uvm_fatal("OUT_MONITOR", "无法获取读接口r_if")
        end
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            @(vif.rmon_cb);  // 在读时钟域采样
            
            // 仅在复位释放后监测有效信号
            if(vif.rrst_n) begin
                my_transaction tr = my_transaction::type_id::create("tr");
                
                // 采样读时钟域信号
                tr.rdata  = vif.rmon_cb.rdata;
                tr.rinc   = vif.rmon_cb.rinc;
                tr.rempty = vif.rmon_cb.rempty;
                
                // 发送事务到分析端口(通常连接到scoreboard)
                if(tr.rinc) begin  // 仅当有读操作时发送
                    ap.write(tr);
                    `uvm_info("OUT_MONITOR", $sformatf("监测到读操作: %s", tr.convert2string()), UVM_HIGH)
                end
            end
        end
    endtask
endclass

`endif
