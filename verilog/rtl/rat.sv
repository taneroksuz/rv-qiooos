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

  logic [PRF_ADDR_BITS:0] eff[0:2*ISSUE_WIDTH-1];
  logic [PRF_ADDR_BITS:0] old[  0:ISSUE_WIDTH-1];

  logic [              4:0] rsrc_a [0:2*ISSUE_WIDTH-1];
  logic [              4:0] waddr_a[  0:ISSUE_WIDTH-1];
  logic [PRF_ADDR_BITS-1:0] waddr_p[  0:ISSUE_WIDTH-1];
  logic [              0:0] wren   [  0:ISSUE_WIDTH-1];

  always_comb begin
    for (int i = 0; i < 2 * ISSUE_WIDTH; i++) begin
      rsrc_a[i] = rat_in.rsrc_a[i];
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      waddr_a[i] = rat_in.waddr_a[i];
      waddr_p[i] = rat_in.waddr_p[i];
      wren[i]    = rat_in.wren[i];
    end

    for (int r = 0; r < 2 * ISSUE_WIDTH; r++) begin
      eff[r] = flush ? comm[rsrc_a[r]] : spec[rsrc_a[r]];
      if (!flush) begin
        for (int c = 0; c < ISSUE_WIDTH; c++) begin
          if (rat_in.commit_en[c] && (rat_in.commit_addr[c] != 5'h0) &&
              (rsrc_a[r] == rat_in.commit_addr[c]) &&
              (eff[r][PRF_ADDR_BITS-1:0] == rat_in.commit_tag[c])) begin
            eff[r] = {1'b1, rat_in.commit_tag[c]};
          end
        end
      end
    end

    for (int r = 0; r < 2 * ISSUE_WIDTH; r++) begin
      for (int w = 0; w < r / 2; w++) begin
        if (wren[w] && (rsrc_a[r] == waddr_a[w]) && (waddr_a[w] != 5'h0)) begin
          eff[r] = {1'b0, waddr_p[w]};
        end
      end
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      old[k] = flush ? comm[waddr_a[k]] : spec[waddr_a[k]];
      for (int w = 0; w < k; w++) begin
        if (wren[w] && (waddr_a[w] == waddr_a[k]) && (waddr_a[w] != 5'h0)) begin
          old[k] = {1'b0, waddr_p[w]};
        end
      end
    end

    rat_out = init_rat_out;
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      rat_out.old_pdest[k] = old[k][PRF_ADDR_BITS-1:0];
    end

    for (int r = 0; r < 2 * ISSUE_WIDTH; r++) begin
      rat_out.psrc[r]       = eff[r][PRF_ADDR_BITS-1:0];
      rat_out.psrc_valid[r] = eff[r][PRF_ADDR_BITS];
    end
  end

  always_ff @(posedge clock) begin
    if (reset != 0) begin
      if (flush) begin
        for (int j = 0; j < ARCH_REGS; j++) begin
          spec[j] <= comm[j];
        end
      end

      for (int c = 0; c < ISSUE_WIDTH; c++) begin
        if (rat_in.commit_en[c] && (rat_in.commit_addr[c] != 5'h0)) begin
          comm[rat_in.commit_addr[c]] <= {1'b1, rat_in.commit_tag[c]};
          if (flush) begin
            spec[rat_in.commit_addr[c]] <= {1'b1, rat_in.commit_tag[c]};
          end else if (spec[rat_in.commit_addr[c]][PRF_ADDR_BITS-1:0] == rat_in.commit_tag[c]) begin
            spec[rat_in.commit_addr[c]] <= {1'b1, rat_in.commit_tag[c]};
          end
        end
      end

      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (wren[k] && (waddr_a[k] != 5'h0)) begin
          spec[waddr_a[k]] <= {1'b0, waddr_p[k]};
        end
      end
    end
  end
endmodule
