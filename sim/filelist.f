# RTL设计文件
../rtl/asyn_fifo.sv
../rtl/fifomem.sv
../rtl/rptr_empty.sv
../rtl/sync_r2w.sv
../rtl/sync_w2r.sv
../rtl/wptr_full.sv

# UVM验证环境文件
../vip/my_if.sv
../vip/my_transaction.sv
../vip/my_sequencer.sv
../vip/my_sequence.sv
../vip/my_driver.sv
../vip/in_monitor.sv
../vip/out_monitor.sv
../vip/i_agt.sv
../vip/o_agt.sv
../vip/my_model.sv
../vip/my_scoreboard.sv
../vip/fifo_rst_mon.sv
../vip/fifo_chk_rst.sv
../vip/my_env.sv

# 测试用例文件
../vip/base_test.sv
../tc/normal_rw_test.sv
../tc/empty_test.sv
../tc/full_test.sv
../tc/abnormal_test.sv
../tc/boundary_test.sv

# 顶层测试平台
../tb/top_tb.sv
