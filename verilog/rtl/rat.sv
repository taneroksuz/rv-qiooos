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

  logic [PRF_ADDR_BITS:0] spec[0:ARCH_REGS-1] = '{
      0: {1'b1, PRF_ADDR_BITS'(0)},
      1: {1'b1, PRF_ADDR_BITS'(1)},
      2: {1'b1, PRF_ADDR_BITS'(2)},
      3: {1'b1, PRF_ADDR_BITS'(3)},
      4: {1'b1, PRF_ADDR_BITS'(4)},
      5: {1'b1, PRF_ADDR_BITS'(5)},
      6: {1'b1, PRF_ADDR_BITS'(6)},
      7: {1'b1, PRF_ADDR_BITS'(7)},
      8: {1'b1, PRF_ADDR_BITS'(8)},
      9: {1'b1, PRF_ADDR_BITS'(9)},
      10: {1'b1, PRF_ADDR_BITS'(10)},
      11: {1'b1, PRF_ADDR_BITS'(11)},
      12: {1'b1, PRF_ADDR_BITS'(12)},
      13: {1'b1, PRF_ADDR_BITS'(13)},
      14: {1'b1, PRF_ADDR_BITS'(14)},
      15: {1'b1, PRF_ADDR_BITS'(15)},
      16: {1'b1, PRF_ADDR_BITS'(16)},
      17: {1'b1, PRF_ADDR_BITS'(17)},
      18: {1'b1, PRF_ADDR_BITS'(18)},
      19: {1'b1, PRF_ADDR_BITS'(19)},
      20: {1'b1, PRF_ADDR_BITS'(20)},
      21: {1'b1, PRF_ADDR_BITS'(21)},
      22: {1'b1, PRF_ADDR_BITS'(22)},
      23: {1'b1, PRF_ADDR_BITS'(23)},
      24: {1'b1, PRF_ADDR_BITS'(24)},
      25: {1'b1, PRF_ADDR_BITS'(25)},
      26: {1'b1, PRF_ADDR_BITS'(26)},
      27: {1'b1, PRF_ADDR_BITS'(27)},
      28: {1'b1, PRF_ADDR_BITS'(28)},
      29: {1'b1, PRF_ADDR_BITS'(29)},
      30: {1'b1, PRF_ADDR_BITS'(30)},
      31: {1'b1, PRF_ADDR_BITS'(31)}
  };

  logic [PRF_ADDR_BITS:0] comm[0:ARCH_REGS-1] = '{
      0: {1'b1, PRF_ADDR_BITS'(0)},
      1: {1'b1, PRF_ADDR_BITS'(1)},
      2: {1'b1, PRF_ADDR_BITS'(2)},
      3: {1'b1, PRF_ADDR_BITS'(3)},
      4: {1'b1, PRF_ADDR_BITS'(4)},
      5: {1'b1, PRF_ADDR_BITS'(5)},
      6: {1'b1, PRF_ADDR_BITS'(6)},
      7: {1'b1, PRF_ADDR_BITS'(7)},
      8: {1'b1, PRF_ADDR_BITS'(8)},
      9: {1'b1, PRF_ADDR_BITS'(9)},
      10: {1'b1, PRF_ADDR_BITS'(10)},
      11: {1'b1, PRF_ADDR_BITS'(11)},
      12: {1'b1, PRF_ADDR_BITS'(12)},
      13: {1'b1, PRF_ADDR_BITS'(13)},
      14: {1'b1, PRF_ADDR_BITS'(14)},
      15: {1'b1, PRF_ADDR_BITS'(15)},
      16: {1'b1, PRF_ADDR_BITS'(16)},
      17: {1'b1, PRF_ADDR_BITS'(17)},
      18: {1'b1, PRF_ADDR_BITS'(18)},
      19: {1'b1, PRF_ADDR_BITS'(19)},
      20: {1'b1, PRF_ADDR_BITS'(20)},
      21: {1'b1, PRF_ADDR_BITS'(21)},
      22: {1'b1, PRF_ADDR_BITS'(22)},
      23: {1'b1, PRF_ADDR_BITS'(23)},
      24: {1'b1, PRF_ADDR_BITS'(24)},
      25: {1'b1, PRF_ADDR_BITS'(25)},
      26: {1'b1, PRF_ADDR_BITS'(26)},
      27: {1'b1, PRF_ADDR_BITS'(27)},
      28: {1'b1, PRF_ADDR_BITS'(28)},
      29: {1'b1, PRF_ADDR_BITS'(29)},
      30: {1'b1, PRF_ADDR_BITS'(30)},
      31: {1'b1, PRF_ADDR_BITS'(31)}
  };

  typedef struct packed {
    logic [ARCH_REGS-1:0][PRF_ADDR_BITS:0]     spec_next;
    logic [ARCH_REGS-1:0][PRF_ADDR_BITS:0]     comm_next;
    logic [2*ISSUE_WIDTH-1:0][PRF_ADDR_BITS:0] eff;
    logic [ISSUE_WIDTH-1:0][PRF_ADDR_BITS:0]   old;
    logic [2*ISSUE_WIDTH-1:0][4:0]             rsrc_a;
    logic [ISSUE_WIDTH-1:0][4:0]               waddr_a;
    logic [ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0] waddr_p;
    logic [ISSUE_WIDTH-1:0][0:0]               wren;
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
      for (int c = 0; c < ISSUE_WIDTH; c++) begin
        if (rat_in.commit_valid[c] && (rat_in.commit_addr[c] != 5'h0) && (v.rsrc_a[r] == rat_in.commit_addr[c]) &&
            (v.eff[r][PRF_ADDR_BITS-1:0] == rat_in.commit_tag[c])) begin
          v.eff[r] = {1'b1, rat_in.commit_tag[c]};
        end
      end
    end

    for (int r = 0; r < 2 * ISSUE_WIDTH; r++) begin
      for (int w = 0; w < r / 2; w++) begin
        if (v.wren[w] && (v.rsrc_a[r] == v.waddr_a[w]) && (v.waddr_a[w] != 5'h0)) begin
          v.eff[r] = {1'b0, v.waddr_p[w]};
        end
      end
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.old[k] = spec[v.waddr_a[k]];
      for (int w = 0; w < k; w++) begin
        if (v.wren[w] && (v.waddr_a[w] == v.waddr_a[k]) && (v.waddr_a[w] != 5'h0)) begin
          v.old[k] = {1'b0, v.waddr_p[w]};
        end
      end
    end

    rat_out = init_rat_out;
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      rat_out.old_pdest[k] = v.old[k][PRF_ADDR_BITS-1:0];
    end

    for (int r = 0; r < 2 * ISSUE_WIDTH; r++) begin
      rat_out.psrc[r]       = v.eff[r][PRF_ADDR_BITS-1:0];
      rat_out.psrc_valid[r] = v.eff[r][PRF_ADDR_BITS];
    end

    for (int j = 0; j < ARCH_REGS; j++) begin
      v.spec_next[j] = flush ? comm[j] : spec[j];
      v.comm_next[j] = comm[j];
      for (int c = 0; c < ISSUE_WIDTH; c++) begin
        if (rat_in.commit_valid[c] && (rat_in.commit_addr[c] != 5'h0) && (rat_in.commit_addr[c] == 5'(j))) begin
          v.comm_next[j] = {1'b1, rat_in.commit_tag[c]};
          if (flush || (spec[j][PRF_ADDR_BITS-1:0] == rat_in.commit_tag[c])) begin
            v.spec_next[j] = {1'b1, rat_in.commit_tag[c]};
          end
        end
      end
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (v.wren[k] && (v.waddr_a[k] != 5'h0) && (v.waddr_a[k] == 5'(j))) begin
          v.spec_next[j] = {1'b0, v.waddr_p[k]};
        end
      end
    end
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      for (int j = 0; j < ARCH_REGS; j++) begin
        spec[j] <= {1'b1, PRF_ADDR_BITS'(j)};
        comm[j] <= {1'b1, PRF_ADDR_BITS'(j)};
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
