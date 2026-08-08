import configure::*;
import constants::*;
import wires::*;
import functions::*;

module post_fetch (
  input  logic               reset,
  input  logic               clock,
  input  logic               flush,
  input  logic               stall,
  input  post_fetch_in_type  post_fetch_in,
  output post_fetch_out_type post_fetch_out
);
  timeunit 1ns; timeprecision 1ps;

  post_fetch_reg_type r, rin;
  post_fetch_reg_type v;

  logic clear;

  always_comb begin

    v = r;

    clear = post_fetch_in.btac_out.pred[0].taken | post_fetch_in.btac_out.pred[1].taken |
        post_fetch_in.btac_out.pred[2].taken | post_fetch_in.btac_out.pred[3].taken;

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      v.pc[i]    = post_fetch_in.pc[i];
      v.instr[i] = post_fetch_in.instr[i];
      v.ready[i] = post_fetch_in.ready[i];
    end

    if (stall == 1) begin
      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        v.pc[i]    = r.pc[i];
        v.instr[i] = r.instr[i];
        v.ready[i] = r.ready[i];
      end
    end

    if ((flush | clear) == 1) begin
      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        v.pc[i]    = 32'hFFFFFFFF;
        v.instr[i] = 0;
        v.ready[i] = 0;
      end
    end

    rin = v;

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      post_fetch_out.pc[i]    = r.pc[i];
      post_fetch_out.instr[i] = r.instr[i];
      post_fetch_out.ready[i] = r.ready[i];
    end

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_post_fetch_reg;
    end else begin
      r <= rin;
    end
  end

endmodule
