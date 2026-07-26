package btac_wires;
  timeunit 1ns; timeprecision 1ps;

  import configure::*;

  localparam B_DEPTH = $clog2(BTB_DEPTH);
  localparam T_DEPTH = $clog2(BHT_DEPTH);

  typedef struct packed {
    logic [0 : 0]              wen;
    logic [B_DEPTH-1 : 0]      waddr;
    logic [3:0][B_DEPTH-1 : 0] raddr;
    logic [64-B_DEPTH : 0]     wdata;
  } btb_in_type;

  typedef struct packed {logic [3:0][64-B_DEPTH : 0] rdata;} btb_out_type;

  typedef struct packed {
    logic [0 : 0]              wen;
    logic [T_DEPTH-1 : 0]      waddr;
    logic [3:0][T_DEPTH-1 : 0] raddr;
    logic [1 : 0]              wdata;
  } bht_in_type;

  typedef struct packed {logic [3:0][1 : 0] rdata;} bht_out_type;

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

  logic [64-B_DEPTH:0] btb_array[0:BTB_DEPTH-1] = '{default: '0};

  always_ff @(posedge clock) begin
    if (btb_in.wen == 1) begin
      btb_array[btb_in.waddr] <= btb_in.wdata;
    end
    for (int k = 0; k < 4; k++) begin
      btb_out.rdata[k] <= btb_array[btb_in.raddr[k]];
    end
  end

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

  localparam T_DEPTH = $clog2(BHT_DEPTH);

  logic [1:0] bht_array[0:BHT_DEPTH-1] = '{default: '0};

  always_ff @(posedge clock) begin
    if (bht_in.wen == 1) begin
      bht_array[bht_in.waddr] <= bht_in.wdata;
    end
    for (int k = 0; k < 4; k++) begin
      bht_out.rdata[k] <= bht_array[bht_in.raddr[k]];
    end
  end

endmodule

module btac_ctrl (
  input  logic         reset,
  input  logic         clock,
  input  btac_in_type  btac_in,
  output btac_out_type btac_out,
  input  btb_out_type  btb_out,
  output btb_in_type   btb_in,
  input  bht_out_type  bht_out,
  output bht_in_type   bht_in
);
  timeunit 1ns; timeprecision 1ps;

  localparam B_DEPTH = $clog2(BTB_DEPTH);
  localparam T_DEPTH = $clog2(BHT_DEPTH);

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
    logic [B_DEPTH-1 : 0]      waddr;
    logic [3:0][B_DEPTH-1 : 0] raddr;
    logic [64-B_DEPTH : 0]     wdata;
    logic [0 : 0]              wen;
    logic [3:0][31 : 0]        pc;
    logic [1:0][31 : 0]        maddr;
    logic [1:0][0 : 0]         miss;
    logic [1:0][0 : 0]         hit;
    logic [3:0][0 : 0]         valid;
    logic [3:0][0 : 0]         branch;
    logic [3:0][0 : 0]         match;
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
    logic [T_DEPTH-1 : 0]      waddr;
    logic [3:0][T_DEPTH-1 : 0] raddr;
    logic [1 : 0]              wdata;
    logic [0 : 0]              wen;
    logic [1:0][1 : 0]         sat;
  } bht_reg_type;

  parameter bht_reg_type init_bht_reg = '{
      waddr : 0,
      raddr : '{default: 0},
      wdata : 0,
      wen : 0,
      sat : '{default: 0}
  };

  btb_reg_type r_btb, rin_btb, v_btb;
  bht_reg_type r_bht, rin_bht, v_bht;

  logic sel[0:1];

  always_comb begin

    v_btb = r_btb;
    v_bht = r_bht;

    for (int k = 0; k < 4; k++) begin
      v_btb.pc[k] = btac_in.get_pc[k];
      v_btb.raddr[k] = btac_in.get_pc[k][B_DEPTH:1];
      v_bht.raddr[k] = btac_in.get_pc[k][T_DEPTH:1];
      btb_in.raddr[k] = v_btb.raddr[k];
      bht_in.raddr[k] = v_bht.raddr[k];
      btac_out.pred[k].taddr = btb_out.rdata[k][31:0];
      v_btb.match[k] = (btb_out.rdata[k][62-B_DEPTH:32] == r_btb.pc[k][31:B_DEPTH+1]);
      v_btb.branch[k] = btb_out.rdata[k][63-B_DEPTH];
      v_btb.valid[k] = btb_out.rdata[k][64-B_DEPTH];
      btac_out.pred[k].taken = v_btb.branch[k] ?
          bht_out.rdata[k][1] & v_btb.match[k] & v_btb.valid[k] : v_btb.match[k] & v_btb.valid[k];
      btac_out.pred[k].tsat = bht_out.rdata[k];
    end

    for (int p = 0; p < 2; p++) begin
      v_btb.maddr[p] = 0;
      v_btb.miss[p]  = 0;
      v_btb.hit[p]   = 0;
    end

    for (int p = 0; p < 2; p++) begin
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

    v_btb.wen = sel[0] | sel[1];
    v_btb.waddr = sel[0] ? btac_in.upd_pc[0][B_DEPTH:1] : btac_in.upd_pc[1][B_DEPTH:1];
    v_btb.wdata = sel[0] ?
        {1'b1, btac_in.upd_branch[0], btac_in.upd_pc[0][31:B_DEPTH+1], v_btb.maddr[0]} :
        {1'b1, btac_in.upd_branch[1], btac_in.upd_pc[1][31:B_DEPTH+1], v_btb.maddr[1]};

    v_bht.wen    = (sel[0] & btac_in.upd_branch[0]) | (sel[1] & btac_in.upd_branch[1]);
    v_bht.waddr  = sel[0] ? btac_in.upd_pc[0][T_DEPTH:1] : btac_in.upd_pc[1][T_DEPTH:1];
    v_bht.sat[0] = saturation(btac_in.upd_pred[0].tsat, btac_in.upd_jump[0]);
    v_bht.sat[1] = saturation(btac_in.upd_pred[1].tsat, btac_in.upd_jump[1]);
    v_bht.wdata  = sel[0] ? v_bht.sat[0] : v_bht.sat[1];

    btb_in.wen   = v_btb.wen;
    btb_in.waddr = v_btb.waddr;
    btb_in.wdata = v_btb.wdata;
    bht_in.wen   = v_bht.wen;
    bht_in.waddr = v_bht.waddr;
    bht_in.wdata = v_bht.wdata;

    rin_btb = v_btb;
    rin_bht = v_bht;

    for (int p = 0; p < 2; p++) begin
      btac_out.pred_maddr[p] = v_btb.maddr[p];
      btac_out.pred_miss[p]  = v_btb.miss[p];
    end
    btac_out.pred_maddr[2] = 0;
    btac_out.pred_maddr[3] = 0;
    btac_out.pred_miss[2]  = 0;
    btac_out.pred_miss[3]  = 0;

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r_btb <= init_btb_reg;
      r_bht <= init_bht_reg;
    end else begin
      r_btb <= rin_btb;
      r_bht <= rin_bht;
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

      btac_ctrl btac_ctrl_comp (
        .reset   (reset),
        .clock   (clock),
        .btac_in (btac_in),
        .btac_out(btac_out),
        .btb_in  (btb_in),
        .btb_out (btb_out),
        .bht_in  (bht_in),
        .bht_out (bht_out)
      );

    end else begin

      typedef struct packed {
        logic [1:0][31 : 0] maddr;
        logic [1:0][0 : 0]  miss;
      } reg_type;

      parameter reg_type init_reg = '{maddr : '{default: 0}, miss : '{default: 0}};

      reg_type r, rin, v;

      always_comb begin

        v = r;

        for (int p = 0; p < 2; p++) begin
          v.maddr[p] = btac_in.upd_addr[p];
          v.miss[p]  = btac_in.upd_jump[p];
        end

        rin = v;

        for (int k = 0; k < 4; k++) begin
          btac_out.pred[k].taken = 0;
          btac_out.pred[k].taddr = 0;
          btac_out.pred[k].tsat  = 0;
        end
        for (int p = 0; p < 2; p++) begin
          btac_out.pred_maddr[p] = v.maddr[p];
          btac_out.pred_miss[p]  = v.miss[p];
        end
        btac_out.pred_maddr[2] = 0;
        btac_out.pred_maddr[3] = 0;
        btac_out.pred_miss[2]  = 0;
        btac_out.pred_miss[3]  = 0;

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
