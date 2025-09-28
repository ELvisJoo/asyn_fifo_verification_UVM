`ifndef IN_MONITOR_SV
`define IN_MONITOR_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/my_transaction.sv"
`include "./vip/my_if.sv"

// 输入monitor:监测写时钟域的输入信号
class in_monitor extends uvm_monitor;
    uvm_analysis_port #(my_transaction) ap;  // 分析端口,发送监测到的事务
    
    virtual my_if.WMONITOR vif;  // 虚拟接口,写监测视角
    
    `uvm_component_utils(in_monitor)
    
    function new(string name = "in_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);  // 初始化分析端口
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 从配置数据库获取接口
        if(!uvm_config_db#(virtual my_if.WMONITOR)::get(this, "", "w_if", vif)) begin
            `uvm_fatal("IN_MONITOR", "无法获取写接口w_if")
        end
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            @(vif.wmon_cb);  // 在写时钟域采样
            
            // 仅在复位释放后监测有效信号
            if(vif.wrst_n) begin
                my_transaction tr = my_transaction::type_id::create("tr");
                
                // 采样写时钟域信号
                tr.wdata = vif.wmon_cb.wdata;
                tr.winc  = vif.wmon_cb.winc;
                tr.wfull = vif.wmon_cb.wfull;
                
                // 发送事务到分析端口(通常连接到reference model或scoreboard)
                if(tr.winc) begin  // 仅当有写操作时发送
                    ap.write(tr);
                    `uvm_info("IN_MONITOR", $sformatf("监测到写操作: %s", tr.convert2string()), UVM_HIGH)
                end
            end
        end
    endtask
endclass

`endif

//  'in_monitor' 'out_monitor'分别针对异步FIFO的写时钟域和读时钟域进行信号监测:

// 1. **in_monitor(输入monitor)**:
//    - 工作在写时钟域(`wclk`),通过`WMONITOR` modport监测信号
//    - 主要监测写数据(`wdata`)、写使能(`winc`)和写满标志(`wfull`)
//    - 当检测到有效写操作(`winc=1`)时,将事务通过分析端口`ap`发送给后续组件(如reference model或scoreboard)
//    - 复位期间不进行有效监测

// 2. **out_monitor(输出monitor)**:
//    - 工作在读时钟域(`rclk`),通过`RMONITOR` modport监测信号
//    - 主要监测读数据(`rdata`)、读使能(`rinc`)和读空标志(`rempty`)
//    - 当检测到有效读操作(`rinc=1`)时,将事务通过分析端口`ap`发送给scoreboard
//    - 同样在复位期间不进行有效监测

// 3. **跨时钟域考虑**:
//    - 两个monitor分别在各自的时钟域下采样,避免跨时钟域采样带来的问题
//    - 事务中包含了各自时钟域的状态信号(`wfull`/`rempty`),便于后续验证分析
