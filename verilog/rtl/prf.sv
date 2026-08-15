import configure::*;
import wires::*;
import functions::*;
module prf (
  input  logic        reset,
  input  logic        clock,
  input  prf_in_type  prf_in,
  output prf_out_type prf_out
);
  timeunit 1ns; timeprecision 1ps;

  logic [31:0] mem[0:ARCH_REGS-1] = '{default: '0};

  logic [ 0:0] wen  [  0:ISSUE_WIDTH-1];
  logic [ 4:0] waddr[  0:ISSUE_WIDTH-1];
  logic [31:0] wdata[  0:ISSUE_WIDTH-1];
  logic [ 4:0] raddr[0:2*ISSUE_WIDTH-1];
  logic [31:0] rdata[0:2*ISSUE_WIDTH-1];

  always_comb begin
    for (int w = 0; w < ISSUE_WIDTH; w++) begin
      wen[w]   = prf_in.wren[w] && (prf_in.waddr[w] != '0);
      waddr[w] = prf_in.waddr[w];
      wdata[w] = prf_in.wdata[w];
    end

    for (int i = 0; i < 2 * ISSUE_WIDTH; i++) begin
      raddr[i] = prf_in.raddr[i];
    end

    prf_out = init_prf_out;

    for (int i = 0; i < 2 * ISSUE_WIDTH; i++) begin
      rdata[i] = mem[raddr[i]];
      for (int w = 0; w < ISSUE_WIDTH; w++) begin
        if (wen[w] && waddr[w] == raddr[i]) begin
          rdata[i] = wdata[w];
        end
      end
    end

    for (int i = 0; i < 2 * ISSUE_WIDTH; i++) begin
      prf_out.rdata[i]  = rdata[i];
      prf_out.rvalid[i] = 1'b1;
    end
  end

  always_ff @(posedge clock) begin
    if (reset != 0) begin
      for (int w = 0; w < ISSUE_WIDTH; w++) begin
        if (wen[w]) begin
          mem[waddr[w]] <= wdata[w];
        end
      end
    end
  end
endmodule
