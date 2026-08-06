package btac_wires;
  timeunit 1ns; timeprecision 1ps;

  import configure::*;

  localparam B_DEPTH = $clog2(BTB_DEPTH);
  localparam H_DEPTH = $clog2(BHT_DEPTH);
  localparam T_DEPTH = $clog2(PHT_DEPTH);

  typedef struct packed {
    logic [0:0]                          wen;
    logic [B_DEPTH-1:0]                  waddr;
    logic [ISSUE_WIDTH-1:0][B_DEPTH-1:0] raddr;
    logic [64-B_DEPTH:0]                 wdata;
  } btb_in_type;

  typedef struct packed {logic [ISSUE_WIDTH-1:0][64-B_DEPTH:0] rdata;} btb_out_type;

  typedef struct packed {
    logic [0:0]                          wen;
    logic [H_DEPTH-1:0]                  waddr;
    logic [ISSUE_WIDTH-1:0][H_DEPTH-1:0] raddr;
    logic [T_DEPTH-1:0]                  wdata;
  } bht_in_type;

  typedef struct packed {logic [ISSUE_WIDTH-1:0][T_DEPTH-1:0] rdata;} bht_out_type;

  typedef struct packed {
    logic [0:0]                          wen;
    logic [T_DEPTH-1:0]                  waddr;
    logic [ISSUE_WIDTH-1:0][T_DEPTH-1:0] raddr;
    logic [1:0]                          wdata;
  } pht_in_type;

  typedef struct packed {logic [ISSUE_WIDTH-1:0][1:0] rdata;} pht_out_type;

endpackage

import configure::*;
import wires::*;
import btac_wires::*;

module btb (
  input  logic        clock,
  input  btb_in_type  btb_in,
  output btb_out_type btb_out
);
  timeunit 1ns; timeprecision 1ps;

  localparam B_DEPTH = $clog2(BTB_DEPTH);

  genvar i;

  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : gen_btb_bank
      logic [64-B_DEPTH:0] btb_array[0:BTB_DEPTH-1] = '{default: '0};

      always_ff @(posedge clock) begin
        if (btb_in.wen == 1) begin
          btb_array[btb_in.waddr] <= btb_in.wdata;
        end
      end

      always_ff @(posedge clock) begin
        btb_out.rdata[i] <= btb_array[btb_in.raddr[i]];
      end
    end
  endgenerate

endmodule

import configure::*;
import wires::*;
import btac_wires::*;

module bht (
  input  logic        clock,
  input  bht_in_type  bht_in,
  output bht_out_type bht_out
);
  timeunit 1ns; timeprecision 1ps;

  localparam H_DEPTH = $clog2(BHT_DEPTH);
  localparam T_DEPTH = $clog2(PHT_DEPTH);

  genvar i;

  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : gen_bht_bank
      logic [T_DEPTH-1:0] bht_array[0:BHT_DEPTH-1] = '{default: '0};

      always_ff @(posedge clock) begin
        if (bht_in.wen == 1) begin
          bht_array[bht_in.waddr] <= bht_in.wdata;
        end
      end

      always_ff @(posedge clock) begin
        bht_out.rdata[i] <= bht_array[bht_in.raddr[i]];
      end
    end
  endgenerate

endmodule

import configure::*;
import wires::*;
import btac_wires::*;

module pht (
  input  logic        clock,
  input  pht_in_type  pht_in,
  output pht_out_type pht_out
);
  timeunit 1ns; timeprecision 1ps;

  localparam T_DEPTH = $clog2(PHT_DEPTH);

  genvar i;

  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : gen_pht_bank
      logic [1:0] pht_array[0:PHT_DEPTH-1] = '{default: '0};

      always_ff @(posedge clock) begin
        if (pht_in.wen == 1) begin
          pht_array[pht_in.waddr] <= pht_in.wdata;
        end
      end

      always_ff @(posedge clock) begin
        pht_out.rdata[i] <= pht_array[pht_in.raddr[i]];
      end
    end
  endgenerate

endmodule

module btac_ctrl (
  input  logic         reset,
  input  logic         clock,
  input  btac_in_type  btac_in,
  output btac_out_type btac_out,
  input  btb_out_type  btb_out,
  output btb_in_type   btb_in,
  input  bht_out_type  bht_out,
  output bht_in_type   bht_in,
  input  pht_out_type  pht_out,
  output pht_in_type   pht_in
);
  timeunit 1ns; timeprecision 1ps;

  localparam B_DEPTH = $clog2(BTB_DEPTH);
  localparam H_DEPTH = $clog2(BHT_DEPTH);
  localparam T_DEPTH = $clog2(PHT_DEPTH);

  function [1:0] saturation;
    input logic [1:0] sat;
    input logic [0:0] jump;
    begin
      if (jump == 0 && |sat == 1) saturation = sat - 1;
      else if (jump == 1 && &sat == 0) saturation = sat + 1;
      else saturation = sat;
    end
  endfunction

  typedef struct packed {
    logic [B_DEPTH-1:0]                  waddr;
    logic [ISSUE_WIDTH-1:0][B_DEPTH-1:0] raddr;
    logic [64-B_DEPTH:0]                 wdata;
    logic [0:0]                          wen;
    logic [ISSUE_WIDTH-1:0][31:0]        pc;
    logic [ISSUE_WIDTH-1:0][31:0]        maddr;
    logic [ISSUE_WIDTH-1:0][0:0]         miss;
    logic [ISSUE_WIDTH-1:0][0:0]         hit;
    logic [ISSUE_WIDTH-1:0][0:0]         valid;
    logic [ISSUE_WIDTH-1:0][0:0]         branch;
    logic [ISSUE_WIDTH-1:0][0:0]         match;
  } btb_reg_type;

  parameter btb_reg_type init_btb_reg = '{
      waddr : 0,
      raddr : '{default: 0},
      wdata : 0,
      wen : 0,
      pc : '{default: 0},
      maddr : '{default: 0},
      miss : '{default: 0},
      hit : '{default: 0},
      valid : '{default: 0},
      branch : '{default: 0},
      match : '{default: 0}
  };

  typedef struct packed {
    logic [H_DEPTH-1:0]                  waddr;
    logic [ISSUE_WIDTH-1:0][H_DEPTH-1:0] raddr;
    logic [T_DEPTH-1:0]                  wdata;
    logic [0:0]                          wen;
  } bht_reg_type;

  parameter bht_reg_type init_bht_reg = '{waddr : 0, raddr : '{default: 0}, wdata : 0, wen : 0};

  typedef struct packed {
    logic [T_DEPTH-1:0]                  waddr;
    logic [ISSUE_WIDTH-1:0][T_DEPTH-1:0] raddr;
    logic [1:0]                          wdata;
    logic [0:0]                          wen;
    logic [ISSUE_WIDTH-1:0][1:0]         sat;
  } pht_reg_type;

  parameter pht_reg_type init_pht_reg = '{
      waddr : 0,
      raddr : '{default: 0},
      wdata : 0,
      wen : 0,
      sat : '{default: 0}
  };

  typedef struct packed {
    logic [ISSUE_WIDTH-1:0][31:0]        taddr;
    logic [ISSUE_WIDTH-1:0][0:0]         valid;
    logic [ISSUE_WIDTH-1:0][0:0]         branch;
    logic [ISSUE_WIDTH-1:0][0:0]         match;
    logic [ISSUE_WIDTH-1:0][T_DEPTH-1:0] hist;
  } pred_reg_type;

  parameter pred_reg_type init_pred_reg = '{
      taddr : '{default: 0},
      valid : '{default: 0},
      branch : '{default: 0},
      match : '{default: 0},
      hist : '{default: 0}
  };

  typedef struct packed {
    logic [ISSUE_WIDTH-1:0][31:0]        taddr;
    logic [ISSUE_WIDTH-1:0][0:0]         valid;
    logic [ISSUE_WIDTH-1:0][0:0]         branch;
    logic [ISSUE_WIDTH-1:0][0:0]         match;
    logic [ISSUE_WIDTH-1:0][T_DEPTH-1:0] hist;
    logic [ISSUE_WIDTH-1:0][1:0]         tsat;
  } pred_out_type;

  parameter pred_out_type init_pred_out_reg = '{
      taddr : '{default: 0},
      valid : '{default: 0},
      branch : '{default: 0},
      match : '{default: 0},
      hist : '{default: 0},
      tsat : '{default: 0}
  };

  btb_reg_type r_btb, rin_btb, v_btb;
  bht_reg_type r_bht, rin_bht, v_bht;
  pht_reg_type r_pht, rin_pht, v_pht;
  pred_reg_type r_pred, rin_pred, v_pred;
  pred_out_type r_pred_out, rin_pred_out, v_pred_out;

  logic sel[0:ISSUE_WIDTH-1];

  always_comb begin

    v_btb      = r_btb;
    v_bht      = r_bht;
    v_pht      = r_pht;
    v_pred     = r_pred;
    v_pred_out = r_pred_out;

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v_btb.pc[k]     = btac_in.get_pc[k];
      v_btb.raddr[k]  = btac_in.get_pc[k][B_DEPTH:1];
      v_bht.raddr[k]  = btac_in.get_pc[k][H_DEPTH:1];
      btb_in.raddr[k] = v_btb.raddr[k];
      bht_in.raddr[k] = v_bht.raddr[k];
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v_btb.match[k]  = (btb_out.rdata[k][62-B_DEPTH:32] == r_btb.pc[k][31:B_DEPTH+1]);
      v_btb.branch[k] = btb_out.rdata[k][63-B_DEPTH];
      v_btb.valid[k]  = btb_out.rdata[k][64-B_DEPTH];

      v_pred.taddr[k]  = btb_out.rdata[k][31:0];
      v_pred.valid[k]  = v_btb.valid[k];
      v_pred.branch[k] = v_btb.branch[k];
      v_pred.match[k]  = v_btb.match[k];
      v_pred.hist[k]   = bht_out.rdata[k];

      v_pht.raddr[k]  = v_pred.hist[k];
      pht_in.raddr[k] = v_pht.raddr[k];
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v_pred_out.taddr[k]  = r_pred.taddr[k];
      v_pred_out.valid[k]  = r_pred.valid[k];
      v_pred_out.branch[k] = r_pred.branch[k];
      v_pred_out.match[k]  = r_pred.match[k];
      v_pred_out.hist[k]   = r_pred.hist[k];
      v_pred_out.tsat[k]   = pht_out.rdata[k];
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      btac_out.pred[k].taddr = r_pred_out.taddr[k];
      btac_out.pred[k].taken = r_pred_out.branch[k] ? v_pred_out.tsat[k][1] & r_pred_out.match[k] &
          r_pred_out.valid[k] : r_pred_out.match[k] & r_pred_out.valid[k];
      btac_out.pred[k].tsat = v_pred_out.tsat[k];
      btac_out.pred[k].thist = r_pred_out.hist[k];
    end

    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      v_btb.maddr[p] = 0;
      v_btb.miss[p]  = 0;
      v_btb.hit[p]   = 0;
    end

    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      if (btac_in.upd_pred[p].taken == 1 && btac_in.upd_jump[p] == 1) begin
        v_btb.maddr[p] = btac_in.upd_addr[p];
        v_btb.miss[p]  = |(btac_in.upd_addr[p] ^ btac_in.upd_pred[p].taddr);
        v_btb.hit[p]   = ~v_btb.miss[p];
      end
      if (btac_in.upd_pred[p].taken == 0 && btac_in.upd_jump[p] == 1) begin
        v_btb.maddr[p] = btac_in.upd_addr[p];
        v_btb.miss[p]  = 1;
      end
      if (btac_in.upd_branch[p] == 1 && btac_in.upd_pred[p].taken == 1 &&
          btac_in.upd_jump[p] == 0) begin
        v_btb.maddr[p] = btac_in.upd_npc[p];
        v_btb.miss[p]  = 1;
      end
    end

    sel[0] = v_btb.hit[0] | v_btb.miss[0];
    sel[1] = v_btb.hit[1] | v_btb.miss[1];
    sel[2] = v_btb.hit[2] | v_btb.miss[2];
    sel[3] = v_btb.hit[3] | v_btb.miss[3];

    v_btb.wen = sel[0] | sel[1] | sel[2] | sel[3];
    v_btb.waddr = sel[0] ? btac_in.upd_pc[0][B_DEPTH:1] : sel[1] ? btac_in.upd_pc[1][B_DEPTH:1] :
        sel[2] ? btac_in.upd_pc[2][B_DEPTH:1] : btac_in.upd_pc[3][B_DEPTH:1];
    v_btb.wdata = sel[0] ?
        {1'b1, btac_in.upd_branch[0], btac_in.upd_pc[0][31:B_DEPTH+1], v_btb.maddr[0]} :
        sel[1] ? {1'b1, btac_in.upd_branch[1], btac_in.upd_pc[1][31:B_DEPTH+1], v_btb.maddr[1]} :
        sel[2] ? {1'b1, btac_in.upd_branch[2], btac_in.upd_pc[2][31:B_DEPTH+1], v_btb.maddr[2]} :
        {1'b1, btac_in.upd_branch[3], btac_in.upd_pc[3][31:B_DEPTH+1], v_btb.maddr[3]};

    v_pht.wen = (sel[0] & btac_in.upd_branch[0]) | (sel[1] & btac_in.upd_branch[1]) |
        (sel[2] & btac_in.upd_branch[2]) | (sel[3] & btac_in.upd_branch[3]);
    v_pht.waddr = sel[0] ? btac_in.upd_pred[0].thist[T_DEPTH-1:0] :
        sel[1] ? btac_in.upd_pred[1].thist[T_DEPTH-1:0] :
        sel[2] ? btac_in.upd_pred[2].thist[T_DEPTH-1:0] : btac_in.upd_pred[3].thist[T_DEPTH-1:0];
    v_pht.sat[0] = saturation(btac_in.upd_pred[0].tsat, btac_in.upd_jump[0]);
    v_pht.sat[1] = saturation(btac_in.upd_pred[1].tsat, btac_in.upd_jump[1]);
    v_pht.sat[2] = saturation(btac_in.upd_pred[2].tsat, btac_in.upd_jump[2]);
    v_pht.sat[3] = saturation(btac_in.upd_pred[3].tsat, btac_in.upd_jump[3]);
    v_pht.wdata = sel[0] ? v_pht.sat[0] :
        sel[1] ? v_pht.sat[1] : sel[2] ? v_pht.sat[2] : v_pht.sat[3];

    v_bht.wen = v_pht.wen;
    v_bht.waddr = sel[0] ? btac_in.upd_pc[0][H_DEPTH:1] : sel[1] ? btac_in.upd_pc[1][H_DEPTH:1] :
        sel[2] ? btac_in.upd_pc[2][H_DEPTH:1] : btac_in.upd_pc[3][H_DEPTH:1];
    v_bht.wdata = sel[0] ? {btac_in.upd_pred[0].thist[T_DEPTH-2:0], btac_in.upd_jump[0]} :
        sel[1] ? {btac_in.upd_pred[1].thist[T_DEPTH-2:0], btac_in.upd_jump[1]} :
        sel[2] ? {btac_in.upd_pred[2].thist[T_DEPTH-2:0], btac_in.upd_jump[2]} :
        {btac_in.upd_pred[3].thist[T_DEPTH-2:0], btac_in.upd_jump[3]};

    btb_in.wen   = v_btb.wen;
    btb_in.waddr = v_btb.waddr;
    btb_in.wdata = v_btb.wdata;
    bht_in.wen   = v_bht.wen;
    bht_in.waddr = v_bht.waddr;
    bht_in.wdata = v_bht.wdata;
    pht_in.wen   = v_pht.wen;
    pht_in.waddr = v_pht.waddr;
    pht_in.wdata = v_pht.wdata;

    rin_btb      = v_btb;
    rin_bht      = v_bht;
    rin_pht      = v_pht;
    rin_pred     = v_pred;
    rin_pred_out = v_pred_out;

    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      btac_out.pred_maddr[p] = v_btb.maddr[p];
      btac_out.pred_miss[p]  = v_btb.miss[p];
    end

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r_btb      <= init_btb_reg;
      r_bht      <= init_bht_reg;
      r_pht      <= init_pht_reg;
      r_pred     <= init_pred_reg;
      r_pred_out <= init_pred_out_reg;
    end else begin
      r_btb      <= rin_btb;
      r_bht      <= rin_bht;
      r_pht      <= rin_pht;
      r_pred     <= rin_pred;
      r_pred_out <= rin_pred_out;
    end
  end

endmodule

module btac (
  input  logic         reset,
  input  logic         clock,
  input  btac_in_type  btac_in,
  output btac_out_type btac_out
);
  timeunit 1ns; timeprecision 1ps;

  generate

    if (BTAC_ENABLE == 1) begin

      btb_in_type  btb_in;
      btb_out_type btb_out;
      bht_in_type  bht_in;
      bht_out_type bht_out;
      pht_in_type  pht_in;
      pht_out_type pht_out;

      btb btb_comp (
        .clock  (clock),
        .btb_in (btb_in),
        .btb_out(btb_out)
      );

      bht bht_comp (
        .clock  (clock),
        .bht_in (bht_in),
        .bht_out(bht_out)
      );

      pht pht_comp (
        .clock  (clock),
        .pht_in (pht_in),
        .pht_out(pht_out)
      );

      btac_ctrl btac_ctrl_comp (
        .reset   (reset),
        .clock   (clock),
        .btac_in (btac_in),
        .btac_out(btac_out),
        .btb_in  (btb_in),
        .btb_out (btb_out),
        .bht_in  (bht_in),
        .bht_out (bht_out),
        .pht_in  (pht_in),
        .pht_out (pht_out)
      );

    end else begin

      typedef struct packed {
        logic [1:0][31:0] maddr;
        logic [1:0][0:0]  miss;
      } reg_type;

      parameter reg_type init_reg = '{maddr : '{default: 0}, miss : '{default: 0}};

      reg_type r, rin, v;

      always_comb begin

        v = r;

        for (int p = 0; p < 4; p++) begin
          v.maddr[p] = btac_in.upd_addr[p];
          v.miss[p]  = btac_in.upd_jump[p];
        end

        rin = v;

        for (int k = 0; k < 4; k++) begin
          btac_out.pred[k].taken = 0;
          btac_out.pred[k].taddr = 0;
          btac_out.pred[k].tsat  = 0;
          btac_out.pred[k].thist = 0;
        end
        for (int p = 0; p < 4; p++) begin
          btac_out.pred_maddr[p] = v.maddr[p];
          btac_out.pred_miss[p]  = v.miss[p];
        end

      end

      always_ff @(posedge clock) begin
        if (reset == 0) begin
          r <= init_reg;
        end else begin
          r <= rin;
        end
      end

    end

  endgenerate

endmodule
