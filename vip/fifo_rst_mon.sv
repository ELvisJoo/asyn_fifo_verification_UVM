`ifndef FIFO_RST_MON_SV
`define FIFO_RST_MON_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/my_if.sv"

class fifo_rst_mon extends uvm_monitor;
    // 分析端口:发送复位状态信息(1表示复位,0表示正常)
    uvm_analysis_port #(bit) wrst_ap;  // 写复位状态端口
    uvm_analysis_port #(bit) rrst_ap;  // 读复位状态端口
    
    // 虚拟接口:同时同时访问读写时钟域的复位信号
    virtual my_if vif;
    
    `uvm_component_utils(fifo_rst_mon)
    
    function new(string name = "fifo_rst_mon", uvm_component parent = null);
        super.new(name, parent);
        wrst_ap = new("wrst_ap", this);
        rrst_ap = new("rrst_ap", this);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 从配置数据库获取接口
        if (!uvm_config_db#(virtual my_if)::get(this, "", "my_if", vif)) begin
            `uvm_fatal("RST_MON", "无法获取接口my_if")
        end
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        // 并行监测写复位和读复位信号
        fork
            monitor_wrst();  // 监测写时钟域复位
            monitor_rrst();  // 监测读时钟域复位
        join
    endtask
    
    // 监测写时钟域复位信号(wrst_n,低有效)
    virtual task monitor_wrst();
        bit prev_wrst = 1'b1;  // 初始为非复位状态
        forever begin
            @(negedge vif.wclk);  // 写时钟域采样
            
            // 检测复位信号变化
            if (vif.wrst_n !== prev_wrst) begin
                if (!vif.wrst_n) begin
                    `uvm_info("RST_MON", "检测到写时钟域复位开始", UVM_MEDIUM)
                    wrst_ap.write(1'b1);  // 发送复位开始信号
                end else begin
                    `uvm_info("RST_MON", "检测到写时钟域复位结束", UVM_MEDIUM)
                    wrst_ap.write(1'b0);  // 发送复位结束信号
                end
                prev_wrst = vif.wrst_n;
            end
        end
    endtask
    
    // 监测读时钟域复位信号(rrst_n,低有效)
    virtual task monitor_rrst();
        bit prev_rrst = 1'b1;  // 初始为非复位状态
        forever begin
            @(negedge vif.rclk);  // 读时钟域采样
            
            // 检测复位信号变化
            if (vif.rrst_n !== prev_rrst) begin
                if (!vif.rrst_n) begin
                    `uvm_info("RST_MON", "检测到读时钟域复位开始", UVM_MEDIUM)
                    rrst_ap.write(1'b1);  // 发送复位开始信号
                end else begin
                    `uvm_info("RST_MON", "检测到读时钟域复位结束", UVM_MEDIUM)
                    rrst_ap.write(1'b0);  // 发送复位结束信号
                end
                prev_rrst = vif.rrst_n;
            end
        end
    endtask
endclass

`endif

// ### 代码说明

// 该复位监测器针对异步FIFO的双复位特性(写复位`wrst_n`和读复位`rrst_n`)设计,主要功能如下:

// 1. **双复位监测**:
//    - 通过两个并行线程`monitor_wrst()`和`monitor_rrst()`,分别在写时钟域(`wclk`)和读时钟域(`rclk`)监测复位信号
//    - 支持异步复位信号的独立监测,符合异步FIFO的时钟域隔离特性

// 2. **状态通知**:
//    - 提供两个分析端口`wrst_ap`和`rrst_ap`,分别发送写复位和读复位的状态(1表示复位中,0表示正常)
//    - 当复位信号发生跳变(从有效到无效或反之)时,立即通过端口发送状态更新

// 3. **精准采样**:
//    - 在各自时钟域的下降沿采样复位信号,确保采样稳定性
//    - 记录复位信号的前一状态,仅在发生变化时触发通知,减少冗余信息

// 4. **易用性**:
//    - 无需额外配置,通过`my_if`直接访问复位信号
//    - 详细的日志信息帮助跟踪复位发生的时间和类型

// 该monitor可与复位检查器(`fifo_chk_rst`)配合使用,用于验证复位期间FIFO的行为是否符合预期(如`wfull`和`rempty`的状态变化、数据清空等)。