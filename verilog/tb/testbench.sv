import configure::*;
import wires::*;

module testbench ();
  timeunit 1ns; timeprecision 1ps;

  logic       reset;
  logic       clock;
  logic       sclk;
  logic       mosi;
  logic       miso = 1'b1;
  logic       ss;
  logic       rx = 1'b1;
  logic       tx;
  logic [1:0] clear;

  mem_in_type  ram_in;
  mem_out_type ram_out;

  logic [31:0] host                [0:0];
  logic [31:0] stoptime = 10000000;
  logic [31:0] counter = 0;

  integer reg_file;
  integer csr_file;
  integer mem_file;

  initial begin
    $readmemh("host.dat", host);
  end

  initial begin
    string filename;
    if ($value$plusargs("FILENAME=%s", filename)) begin
      $dumpfile(filename);
      $dumpvars(0, testbench);
    end
  end

  initial begin
    string maxtime;
    if ($value$plusargs("MAXTIME=%s", maxtime)) begin
      stoptime = maxtime.atoi();
    end
  end

  initial begin
    reset = 0;
    clock = 1;
  end

  initial begin
    #10 reset = 1;
  end

  always #0.5 clock = ~clock;

  always_ff @(posedge clock) begin
    if (counter == stoptime) begin
      $finish;
    end else begin
      counter <= counter + 1;
    end
  end

  wire        commit_valid [0:ISSUE_WIDTH-1];
  wire [31:0] commit_pc    [0:ISSUE_WIDTH-1];
  wire [ 4:0] commit_waddr [0:ISSUE_WIDTH-1];
  wire [31:0] commit_wdata [0:ISSUE_WIDTH-1];
  wire        commit_wren  [0:ISSUE_WIDTH-1];
  wire        commit_store [0:ISSUE_WIDTH-1];
  wire [31:0] commit_saddr [0:ISSUE_WIDTH-1];
  wire [31:0] commit_sdata [0:ISSUE_WIDTH-1];
  wire [ 3:0] commit_sstrb [0:ISSUE_WIDTH-1];
  wire        commit_cwren [0:ISSUE_WIDTH-1];
  wire [11:0] commit_caddr [0:ISSUE_WIDTH-1];
  wire [31:0] commit_cwdata[0:ISSUE_WIDTH-1];

  for (genvar k = 0; k < ISSUE_WIDTH; k++) begin : g_commit_wires
    assign commit_valid[k]  = testbench.soc_comp.cpu_comp.commit_in.commit_valid[k];
    assign commit_pc[k]     = testbench.soc_comp.cpu_comp.commit_in.entry[k].pc;
    assign commit_waddr[k]  = testbench.soc_comp.cpu_comp.commit_in.entry[k].adest;
    assign commit_wdata[k]  = testbench.soc_comp.cpu_comp.commit_in.entry[k].result;
    assign commit_wren[k]   = testbench.soc_comp.cpu_comp.commit_in.entry[k].wren;
    assign commit_store[k]  = testbench.soc_comp.cpu_comp.commit_in.entry[k].store;
    assign commit_saddr[k]  = testbench.soc_comp.cpu_comp.commit_in.entry[k].store_addr;
    assign commit_sdata[k]  = testbench.soc_comp.cpu_comp.commit_in.entry[k].store_data;
    assign commit_sstrb[k]  = testbench.soc_comp.cpu_comp.commit_in.entry[k].store_strb;
    assign commit_cwren[k]  = testbench.soc_comp.cpu_comp.commit_in.entry[k].cwren;
    assign commit_caddr[k]  = testbench.soc_comp.cpu_comp.commit_in.entry[k].caddr;
    assign commit_cwdata[k] = testbench.soc_comp.cpu_comp.commit_in.entry[k].cwdata;
  end

  initial begin
    string filename;
    if ($value$plusargs("REGFILE=%s", filename)) begin
      reg_file = $fopen(filename, "w");
      for (int i = 0; i < stoptime; i = i + 1) begin
        @(posedge clock);
        for (int k = 0; k < ISSUE_WIDTH; k++) begin
          if (commit_valid[k] && commit_wren[k]) begin
            $fwrite(reg_file, "PERIOD = %t ;\t", $time);
            $fwrite(reg_file, "PC = %x ;\t", commit_pc[k]);
            $fwrite(reg_file, "WADDR = %x ;\t", commit_waddr[k]);
            $fwrite(reg_file, "WDATA = %x ;\n", commit_wdata[k]);
          end
        end
      end
      $fclose(reg_file);
    end
  end

  initial begin
    string filename;
    if ($value$plusargs("CSRFILE=%s", filename)) begin
      csr_file = $fopen(filename, "w");
      for (int i = 0; i < stoptime; i = i + 1) begin
        @(posedge clock);
        for (int k = 0; k < ISSUE_WIDTH; k++) begin
          if (commit_valid[k] && commit_cwren[k]) begin
            $fwrite(csr_file, "PERIOD = %t ;\t", $time);
            $fwrite(csr_file, "PC = %x ;\t", commit_pc[k]);
            $fwrite(csr_file, "WADDR = %x ;\t", commit_caddr[k]);
            $fwrite(csr_file, "WDATA = %x ;\n", commit_cwdata[k]);
          end
        end
      end
      $fclose(csr_file);
    end
  end

  initial begin
    string filename;
    if ($value$plusargs("MEMFILE=%s", filename)) begin
      mem_file = $fopen(filename, "w");
      for (int i = 0; i < stoptime; i = i + 1) begin
        @(posedge clock);
        for (int k = 0; k < ISSUE_WIDTH; k++) begin
          if (commit_valid[k] && commit_store[k] && |commit_sstrb[k]) begin
            $fwrite(mem_file, "PERIOD = %t ;\t", $time);
            $fwrite(mem_file, "PC = %x ;\t", commit_pc[k]);
            $fwrite(mem_file, "WADDR = %x ;\t", commit_saddr[k]);
            $fwrite(mem_file, "WSTRB = %b ;\t", commit_sstrb[k]);
            $fwrite(mem_file, "WDATA = %x ;\n", commit_sdata[k]);
          end
        end
      end
      $fclose(mem_file);
    end
  end

  always_ff @(posedge clock) begin
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      if (commit_valid[k] && commit_store[k] && |commit_sstrb[k]) begin
        if (commit_saddr[k][31:3] == host[0][31:3]) begin
          $display("%d", commit_sdata[k][31:0]);
          $finish;
        end
      end
    end
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      clear <= 2'b11;
    end else begin
      clear <= {1'b0, clear[1]};
    end
  end

  soc soc_comp (
    .reset  (reset),
    .clear  (clear[0]),
    .clock  (clock),
    .sclk   (sclk),
    .mosi   (mosi),
    .miso   (miso),
    .ss     (ss),
    .rx     (rx),
    .tx     (tx),
    .ram_in (ram_in),
    .ram_out(ram_out)
  );

  ram ram_comp (
    .reset  (reset),
    .clock  (clock),
    .ram_in (ram_in),
    .ram_out(ram_out)
  );

endmodule
