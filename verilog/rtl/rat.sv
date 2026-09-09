import configure::*;
import wires::*;
import functions::*;

module rat (
  input  logic        reset,
  input  logic        clock,
  input  logic        flush,
  input  rat_in_type  rat_in,
  output rat_out_type rat_out
);
  timeunit 1ns; timeprecision 1ps;

  logic [PRF_ADDR_BITS-1:0] spec[0:ARCH_REGS-1];
  logic [PRF_ADDR_BITS-1:0] comm[0:ARCH_REGS-1];

  initial begin
    for (int j = 0; j < ARCH_REGS; j++) begin
      spec[j] = PRF_ADDR_BITS'(j);
      comm[j] = PRF_ADDR_BITS'(j);
    end
  end

  typedef struct packed {
    logic [ARCH_REGS-1:0][PRF_ADDR_BITS-1:0]      spec_next;
    logic [ARCH_REGS-1:0][PRF_ADDR_BITS-1:0]      comm_next;
    logic [2*ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0]  eff;
    logic [ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0]    old;
    logic [2*ISSUE_WIDTH-1:0][AREG_ADDR_BITS-1:0] rsrc_a;
    logic [ISSUE_WIDTH-1:0][AREG_ADDR_BITS-1:0]   waddr_a;
    logic [ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0]    waddr_p;
    logic [ISSUE_WIDTH-1:0][0:0]                  wren;
  } rat_reg_type;

  rat_reg_type v;

  always_comb begin
    for (int i = 0; i < 2 * ISSUE_WIDTH; i++) begin
      v.rsrc_a[i] = rat_in.rsrc_a[i];
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      v.waddr_a[i] = rat_in.waddr_a[i];
      v.waddr_p[i] = rat_in.waddr_p[i];
      v.wren[i]    = rat_in.wren[i];
    end

    for (int r = 0; r < 2 * ISSUE_WIDTH; r++) begin
      v.eff[r] = spec[v.rsrc_a[r]];
      for (int w = 0; w < r / 2; w++) begin
        if (v.wren[w] && (v.rsrc_a[r] == v.waddr_a[w]) && (v.waddr_a[w] != AREG_ADDR_BITS'(0))) begin
          v.eff[r] = v.waddr_p[w];
        end
      end
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.old[k] = spec[v.waddr_a[k]];
      for (int w = 0; w < k; w++) begin
        if (v.wren[w] && (v.waddr_a[w] == v.waddr_a[k]) && (v.waddr_a[w] != AREG_ADDR_BITS'(0))) begin
          v.old[k] = v.waddr_p[w];
        end
      end
    end

    rat_out = init_rat_out;
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      rat_out.old_pdest[k] = v.old[k];
    end

    for (int r = 0; r < 2 * ISSUE_WIDTH; r++) begin
      rat_out.psrc[r] = v.eff[r];
    end

    for (int j = 0; j < ARCH_REGS; j++) begin
      v.comm_next[j] = comm[j];
      for (int c = 0; c < ISSUE_WIDTH; c++) begin
        if (rat_in.commit_valid[c] && (rat_in.commit_addr[c] != AREG_ADDR_BITS'(0)) &&
            (rat_in.commit_addr[c] == AREG_ADDR_BITS'(j))) begin
          v.comm_next[j] = rat_in.commit_tag[c];
        end
      end
      v.spec_next[j] = flush ? v.comm_next[j] : spec[j];
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (v.wren[k] && (v.waddr_a[k] != AREG_ADDR_BITS'(0)) && (v.waddr_a[k] == AREG_ADDR_BITS'(j))) begin
          v.spec_next[j] = v.waddr_p[k];
        end
      end
    end
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      for (int j = 0; j < ARCH_REGS; j++) begin
        spec[j] <= PRF_ADDR_BITS'(j);
        comm[j] <= PRF_ADDR_BITS'(j);
      end
    end
    else begin
      for (int j = 0; j < ARCH_REGS; j++) begin
        spec[j] <= v.spec_next[j];
        comm[j] <= v.comm_next[j];
      end
    end
  end

endmodule
