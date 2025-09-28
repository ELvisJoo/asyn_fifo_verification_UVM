`ifndef BASE_TEST_SV
`define BASE_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/my_env.sv"
`include "./vip/my_if.sv"

class base_test extends uvm_test;
    // 验证环境实例
    my_env env;
    
    // 虚拟接口实例(顶层接口,连接DUT)
    virtual my_if vif;
    
    `uvm_component_utils(base_test)
    
    function new(string name = "base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // 创建验证环境
        env = my_env::type_id::create("env", this);
        
        // 获取虚拟接口并注册到配置数据库
        if (!uvm_config_db#(virtual my_if)::get(this, "", "my_if", vif)) begin
            `uvm_fatal("BASE_TEST", "无法从配置数据库获取虚拟接口my_if")
        end
        
        // 向环境中的组件传递接口
        uvm_config_db#(virtual my_if)::set(this, "env.*", "my_if", vif);
        uvm_config_db#(virtual my_if.WDRIVER)::set(this, "env.i_agent.wdrv*", "w_if", vif);
        uvm_config_db#(virtual my_if.WMONITOR)::set(this, "env.i_agent.wmon*", "w_if", vif);
        uvm_config_db#(virtual my_if.RDRIVER)::set(this, "env.o_agent.rdrv*", "r_if", vif);
        uvm_config_db#(virtual my_if.RMONITOR)::set(this, "env.o_agent.rmon*", "r_if", vif);
    
    endfunction
    
    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        // 打印测试结构
        `uvm_info("TEST_STRUCTURE", $sformatf("测试结构:\n%s", this.sprint()), UVM_LOW)
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        // 启动测试前设置相位 objection,防止仿真提前结束
        phase.raise_objection(this);
        
        // 基础测试流程:等待复位完成后执行简单测试
        `uvm_info("BASE_TEST", "开始基础测试流程...", UVM_MEDIUM)
        
        // 等待复位完成
        wait(vif.wrst_n && vif.rrst_n);
        `uvm_info("BASE_TEST", "读写复位均已释放,开始执行测试", UVM_MEDIUM)
        
        // 基础测试可在此处添加默认序列(如简单的读写操作)
        // 子类可通过重载run_phase实现特定测试流程
        
        // 测试完成后等待几个时钟周期
        repeat(20) @(posedge vif.wclk);
        
        // 测试结束,撤销objection
        phase.drop_objection(this, "基础测试流程结束");
    endtask
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        // 打印测试结果摘要(可扩展错误统计)
        `uvm_info("TEST_SUMMARY", "=====================================", UVM_LOW)
        `uvm_info("TEST_SUMMARY", "基础测试完成!", UVM_LOW)
        `uvm_info("TEST_SUMMARY", "错误统计: 查看日志中'UVM_ERROR'条数", UVM_LOW)
        `uvm_info("TEST_SUMMARY", "=====================================", UVM_LOW)
    endfunction

endclass

`endif
