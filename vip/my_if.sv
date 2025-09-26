`ifndef MY_IF__SV
`define MY_IF__SV

interface my_if(input wclk, input rclk, input wrst_n, input rrst_n);

	logic winc,rinc;
        logic [7 : 0] wdata;
        wire  wfull,rempty;
        logic [7 : 0] rdata;
        //logic wrst_n;
        //logic rrst_n;

  clocking ckw @(posedge wclk);
    input  wfull;
    inout  winc;
    inout  wdata;
  endclocking

  clocking ckim @(posedge wclk);
    input wfull;
    inout  winc;
    input  wdata;
  endclocking

  clocking ckom @(posedge rclk);
    input  rempty;
    inout  rinc;
    input  rdata;
  endclocking
  
  modport DUT(
  input winc,
  input rinc,
  input wdata,
  output rdata,
  output wfull,
  output rempty
  );

 modport DRV(
  clocking ckw,
  input rinc,
  input rdata,
  input rempty
);

 modport OMON(
 clocking ckom,
 input wfull,
 input winc,
 input wdata
);
  
  
  


endinterface
`endif
