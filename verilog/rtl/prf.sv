import configure::*;
import wires::*;
import functions::*;
module prf (
  input  logic        reset,
  input  logic        clock,
  input  logic        flush,
  input  prf_in_type  prf_in,
  output prf_out_type prf_out
);
  timeunit 1ns; timeprecision 1ps;

  typedef struct packed {logic [PRF_DEPTH-1:0] written_bits;} prf_reg_type;
  localparam prf_reg_type init_prf_reg = '{written_bits: '0};

  logic [31:0] mem[0:PRF_DEPTH-1];
  prf_reg_type r, rin, v;

  logic [              0:0] wen  [  0:ISSUE_WIDTH-1];
  logic [PRF_ADDR_BITS-1:0] waddr[  0:ISSUE_WIDTH-1];
  logic [             31:0] wdata[  0:ISSUE_WIDTH-1];
  logic [PRF_ADDR_BITS-1:0] raddr[0:2*ISSUE_WIDTH-1];
  logic [             31:0] rdata[0:2*ISSUE_WIDTH-1];

  always_comb begin
    v = r;

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
      rdata[i] = r.written_bits[raddr[i]] ? mem[raddr[i]] : 32'h0;
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

    for (int w = 0; w < ISSUE_WIDTH; w++) begin
      if (wen[w]) begin
        v.written_bits[waddr[w]] = 1'b1;
      end
    end

    rin = v;
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_prf_reg;
    end else begin
      r <= rin;
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
