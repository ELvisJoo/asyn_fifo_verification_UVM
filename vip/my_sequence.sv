`ifndef MY_SEQUENCE_SV
`define MY_SEQUENCE_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/my_transaction.sv "   

// 基础序列:提供通用功能
class base_sequence extends uvm_sequence #(my_transaction);
    `uvm_object_utils(base_sequence)
    `uvm_declare_p_sequencer(my_sequencer)
    
    function new(string name = "base_sequence");
        super.new(name);
    endfunction
    
    // 等待默认的简单事务
    virtual task body();
        my_transaction tr;
        tr = my_transaction::type_id::create("tr");
        start_item(tr);
        assert(tr.randomize());
        finish_item(tr);
    endtask
endclass

// 1.1连续写序列:连续写入多个数据
class write_sequence extends base_sequence;
    rand int unsigned write_count;  // 写入数据数量
    rand int unsigned delay;        // 事务间延迟
    
    // 约束约束
    constraint c_write_count {
        write_count inside {[5:20]};  // 写入5-20个数据
        delay inside {[0:3]};         // 延迟0-3个时钟周期
    }
    
    `uvm_object_utils(write_sequence)
    
    function new(string name = "write_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        my_transaction tr;
        
        `uvm_info("WRITE_sequence", $sformatf("开始连续写入 %0d 个数据", write_count), UVM_MEDIUM)
        
        repeat(write_count) begin
            tr = my_transaction::type_id::create("tr");
            start_item(tr);
            
            // 约束为只写操作
            assert(tr.randomize() with {
                winc == 1'b1;
                rinc == 1'b0;
            });
            
            finish_item(tr);
            
            // 插入延迟
            repeat(delay) @(posedge p_sequencer.vif.wclk);
        end
        
        `uvm_info("write_sequence", "连续写入完成", UVM_MEDIUM)
    endtask
endclass

// 1.2 连续读序列:连续读取多个数据
class read_sequence extends base_sequence;
    rand int unsigned read_count;   // 读取数据数量
    rand int unsigned delay;        // 事务间延迟
    
    // 约束
    constraint c_read_count {
        read_count inside {[5:20]};   // 读取5-20个数据
        delay inside {[0:3]};         // 延迟0-3个时钟周期
    }
    
    `uvm_object_utils(read_sequence)
    
    function new(string name = "read_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        my_transaction tr;
        
        `uvm_info("read_sequence", $sformatf("开始连续读取 %0d 个数据", read_count), UVM_MEDIUM)
        
        repeat(read_count) begin
            tr = my_transaction::type_id::create("tr");
            start_item(tr);
            
            // 约束为只读操作
            assert(tr.randomize() with {
                winc == 1'b0;
                rinc == 1'b1;
            });
            
            finish_item(tr);
            
            // 插入延迟
            repeat(delay) @(posedge p_sequencer.vif.rclk);
        end
        
        `uvm_info("read_sequence", "连续读取完成", UVM_MEDIUM)
    endtask
endclass

// 2. 交替读写序列:先写后读,交替进行
class rw_alternate_sequence extends base_sequence;
    rand int unsigned loop_count;   // 交替次数
    
    constraint c_loop_count {
        loop_count inside {[3:10]};   // 交替3-10次
    }
    
    `uvm_object_utils(rw_alternate_sequence)
    
    function new(string name = "rw_alternate_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        write_sequence w_seq;
        read_sequence r_seq;
        
        `uvm_info("rw_alternate_sequence", $sformatf("开始交替读写 %0d 次", loop_count), UVM_MEDIUM)
        
        repeat(loop_count) begin
            // 先写一批数据
            w_seq = write_sequence::type_id::create("w_seq");
            assert(w_seq.randomize() with {write_count inside {[2:5]};});
            w_seq.start(p_sequencer);
            
            // 再读一批数据
            r_seq = read_sequence::type_id::create("r_seq");
            assert(r_seq.randomize() with {read_count == w_seq.write_count;});
            r_seq.start(p_sequencer);
        end
        
        `uvm_info("rw_alternate_sequence", "交替读写完成", UVM_MEDIUM)
    endtask
endclass

// 3. 满状态测试序列:写满FIFO后继续尝试写入
class full_test_sequence extends base_sequence;
    `uvm_object_utils(full_test_sequence)
    
    function new(string name = "full_test_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        my_transaction tr;
        int unsigned depth;
        
        // 计算FIFO深度 (2^ADDRSIZEL)
        depth = 1 << p_sequencer.vif.ADDRSIZEL;
        
        `uvm_info("full_test_sequence", $sformatf("开始满状态测试,FIFO深度: %0d", depth), UVM_MEDIUM)
        
        // 1. 先写满FIFO
        repeat(depth) begin
            tr = my_transaction::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with {winc == 1'b1; rinc == 1'b0;});
            finish_item(tr);
        end
        
        // 等待FIFO满标志置位
        @(posedge p_sequencer.vif.wfull);
        `uvm_info("full_test_sequence", "FIFO已写满", UVM_MEDIUM)
        
        // 2. 满状态下继续尝试写入
        repeat(5) begin
            tr = my_transaction::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with {winc == 1'b1; rinc == 1'b0;});
            finish_item(tr);
            @(posedge p_sequencer.vif.wclk);
        end
        
        `uvm_info("full_test_sequence", "满状态测试完成", UVM_MEDIUM)
    endtask
endclass

// 4. 空状态测试序列:读空FIFO后继续尝试读取
class empty_test_sequence extends base_sequence;
    `uvm_object_utils(empty_test_sequence)
    
    function new(string name = "empty_test_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        my_transaction tr;
        
        `uvm_info("empty_test_sequence", "开始空状态测试", UVM_MEDIUM)
        
        // 1. 确保FIFO为空(复位后)
        @(posedge p_sequencer.vif.rempty);
        `uvm_info("empty_test_sequence", "FIFO已为空", UVM_MEDIUM)
        
        // 2. 空状态下继续尝试读取
        repeat(5) begin
            tr = my_transaction::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with {winc == 1'b0; rinc == 1'b1;});
            finish_item(tr);
            @(posedge p_sequencer.vif.rclk);
        end
        
        `uvm_info("empty_test_sequence", "空状态测试完成", UVM_MEDIUM)
    endtask
endclass

// 5. 异常测试序列:包含各种异常场景
class abnormal_test_sequence extends base_sequence;
    `uvm_object_utils(abnormal_test_sequence)
    
    function new(string name = "abnormal_test_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        my_transaction tr;
        write_sequence w_seq;
        read_sequence r_seq;
        int unsigned depth;
        
        depth = 1 << p_sequencer.vif.ADDRSIZEL;
        
        `uvm_info("abnormal_test_sequence", "开始异常场景测试", UVM_MEDIUM)
        
        // 5.1 同时读写操作:生成 3 次 winc=1 且 rinc=1 的操作，验证 FIFO 对并发读写的处理
        `uvm_info("abnormal_test_sequence", "测试同时读写操作", UVM_MEDIUM)
        repeat(3) begin
            tr = my_transaction::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with {winc == 1'b1; rinc == 1'b1;});
            finish_item(tr);
            @(posedge p_sequencer.vif.wclk);
        end
        
        // 5.2 写满后尝试写入,同时读取:先写满 FIFO,再生成 3 次并发读写,验证满状态下的异常处理
        `uvm_info("abnormal_test_sequence", "测试写满后同时读写", UVM_MEDIUM)
        w_seq = write_sequence::type_id::create("w_seq");
        assert(w_seq.randomize() with {write_count == depth;});
        w_seq.start(p_sequencer);
        
        repeat(3) begin
            tr = my_transaction::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with {winc == 1'b1; rinc == 1'b1;});
            finish_item(tr);
            @(posedge p_sequencer.vif.wclk);
        end
        
        // 5.3 读空后尝试读取,同时写入:先读空 FIFO,再生成 3 次并发读写,验证满状态下的异常处理
        `uvm_info("abnormal_test_sequence", "测试读空后同时读写", UVM_MEDIUM)
        r_seq = read_sequence::type_id::create("r_seq");
        assert(r_seq.randomize() with {read_count == depth;});
        r_seq.start(p_sequencer);
        
        repeat(3) begin
            tr = my_transaction::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with {winc == 1'b1; rinc == 1'b1;});
            finish_item(tr);
            @(posedge p_sequencer.vif.wclk);
        end
        
        `uvm_info("abnormal_test_sequence", "异常场景测试完成", UVM_MEDIUM)
    endtask
endclass

`endif

// ** 一。 基础序列
// 1.1. 连续写序列write_sequence:连续写入多个数据(随机生成 5-20 个写事务 winc=1, rinc=0)
// 1.2. 连续读序列read_sequence:连续读取多个数据(随机生成 5-20 个读事务 winc=0, rinc=1)

// ** 二。 功能测试序列
// 2. 交替读写序列rw_alternate_sequence:先写后读,交替进行
//    --计算 FIFO 深度 depth = 1 << ADDRSIZEL 
//    --写满depth个数据,等待wfull置位
//    --满状态下继续写入 5 次，验证保护机制

// ** 三. 边界状态测试序列
// 3. 满状态测试序列full_test_sequence:写满FIFO后,继续尝试写入
// 4. 空状态测试序列empty_test_sequence:读空FIFO后,继续尝试读取

// ** 四. 异常场景测试序列
// 5. 异常测试序列abnormal_test_sequence:包含各种异常场景
//    --同时读写 winc=1 且 rinc=1
//    --满状态下同时读写
//    --空状态下同时读写