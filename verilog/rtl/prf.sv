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

  typedef struct packed {
    logic [ISSUE_WIDTH-1:0][0:0]    wen;
    logic [ISSUE_WIDTH-1:0][4:0]    waddr;
    logic [ISSUE_WIDTH-1:0][31:0]   wdata;
    logic [2*ISSUE_WIDTH-1:0][4:0]  raddr;
    logic [2*ISSUE_WIDTH-1:0][31:0] rdata;
  } prf_reg_type;

  logic [31:0] mem[0:ARCH_REGS-1] = '{default: '0};

  prf_reg_type v;

  always_comb begin
    for (int w = 0; w < ISSUE_WIDTH; w++) begin
      v.wen[w]   = prf_in.wren[w] && (prf_in.waddr[w] != '0);
      v.waddr[w] = prf_in.waddr[w];
      v.wdata[w] = prf_in.wdata[w];
    end

    for (int i = 0; i < 2 * ISSUE_WIDTH; i++) begin
      v.raddr[i] = prf_in.raddr[i];
    end

    prf_out = init_prf_out;

    for (int i = 0; i < 2 * ISSUE_WIDTH; i++) begin
      v.rdata[i] = mem[v.raddr[i]];
      for (int w = 0; w < ISSUE_WIDTH; w++) begin
        if (v.wen[w] && v.waddr[w] == v.raddr[i]) begin
          v.rdata[i] = v.wdata[w];
        end
      end
    end

    for (int i = 0; i < 2 * ISSUE_WIDTH; i++) begin
      prf_out.rdata[i]  = v.rdata[i];
      prf_out.rvalid[i] = 1'b1;
    end
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      for (int i = 0; i < ARCH_REGS; i++) begin
        mem[i] <= '0;
      end
    end
    else begin
      for (int w = 0; w < ISSUE_WIDTH; w++) begin
        if (v.wen[w]) begin
          mem[v.waddr[w]] <= v.wdata[w];
        end
      end
    end
  end
endmodule
