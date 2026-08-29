package btac_wires;
  timeunit 1ns; timeprecision 1ps;

  import configure::*;

  localparam B_DEPTH = $clog2(BTB_DEPTH);
  localparam T_DEPTH = $clog2(BHT_DEPTH);

  typedef struct packed {
    logic [0:0]                          wen;
    logic [B_DEPTH-1:0]                  waddr;
    logic [ISSUE_WIDTH-1:0][B_DEPTH-1:0] raddr;
    logic [64-B_DEPTH:0]                 wdata;
  } btb_in_type;

  typedef struct packed {logic [ISSUE_WIDTH-1:0][64-B_DEPTH:0] rdata;} btb_out_type;

  typedef struct packed {
    logic [0:0]                          wen;
    logic [T_DEPTH-1:0]                  waddr;
    logic [ISSUE_WIDTH-1:0][T_DEPTH-1:0] raddr;
    logic [1:0]                          wdata;
  } bht_in_type;

  typedef struct packed {logic [ISSUE_WIDTH-1:0][1:0] rdata;} bht_out_type;

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

  localparam T_DEPTH = $clog2(BHT_DEPTH);

  genvar i;

  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : gen_bht_bank
      logic [1:0] bht_array[0:BHT_DEPTH-1] = '{default: '0};

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
    logic [ISSUE_WIDTH-1:0][0:0]         alloc;
    logic [ISSUE_WIDTH-1:0][0:0]         upd;
    logic [ISSUE_WIDTH-1:0][0:0]         kill;
    logic [B_DEPTH:0]                    fcount;
  } btb_reg_type;

  localparam btb_reg_type init_btb_reg = '{
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
      match : '{default: 0},
      alloc : '{default: 0},
      upd : '{default: 0},
      kill : '{default: 0},
      fcount : 0
  };

  typedef struct packed {
    logic [T_DEPTH-1:0]                  waddr;
    logic [ISSUE_WIDTH-1:0][T_DEPTH-1:0] raddr;
    logic [1:0]                          wdata;
    logic [0:0]                          wen;
    logic [ISSUE_WIDTH-1:0][1:0]         sat;
    logic [ISSUE_WIDTH-1:0][0:0]         upd;
  } bht_reg_type;

  localparam bht_reg_type init_bht_reg = '{
      waddr : 0,
      raddr : '{default: 0},
      wdata : 0,
      wen : 0,
      sat : '{default: 0},
      upd : '{default: 0}
  };

  btb_reg_type r_btb, rin_btb, v_btb;
  bht_reg_type r_bht, rin_bht, v_bht;

  always_comb begin

    v_btb = r_btb;
    v_bht = r_bht;

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v_btb.pc[k] = btac_in.get_pc[k];
      v_btb.raddr[k] = btac_in.get_pc[k][B_DEPTH:1];
      v_bht.raddr[k] = btac_in.get_pc[k][T_DEPTH:1];
      btb_in.raddr[k] = v_btb.raddr[k];
      bht_in.raddr[k] = v_bht.raddr[k];
      btac_out.pred[k].taddr = btb_out.rdata[k][31:0];
      v_btb.match[k] = (btb_out.rdata[k][62-B_DEPTH:32] == r_btb.pc[k][31:B_DEPTH+1]);
      v_btb.branch[k] = btb_out.rdata[k][63-B_DEPTH];
      v_btb.valid[k] = btb_out.rdata[k][64-B_DEPTH];
      btac_out.pred[k].taken = v_btb.branch[k] ? bht_out.rdata[k][1] & v_btb.match[k] & v_btb.valid[k] :
          v_btb.match[k] & v_btb.valid[k];
      btac_out.pred[k].tsat = bht_out.rdata[k];
      btac_out.pred[k].tmatch = v_btb.match[k] & v_btb.valid[k];
    end

    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      v_btb.maddr[p] = 0;
      v_btb.miss[p]  = 0;
      v_btb.hit[p]   = 0;
      v_btb.kill[p]  = 0;
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
      if (btac_in.upd_branch[p] == 1 && btac_in.upd_pred[p].taken == 1 && btac_in.upd_jump[p] == 0) begin
        v_btb.maddr[p] = btac_in.upd_npc[p];
        v_btb.miss[p]  = 1;
      end
      if (btac_in.upd_branch[p] == 0 && btac_in.upd_jump[p] == 0 && btac_in.upd_pred[p].taken == 1) begin
        v_btb.maddr[p] = btac_in.upd_npc[p];
        v_btb.miss[p]  = 1;
        v_btb.kill[p]  = 1;
      end
    end

    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      v_btb.alloc[p] = (btac_in.upd_branch[p] | btac_in.upd_jump[p]) & ~btac_in.upd_pred[p].tmatch;
      v_btb.upd[p]   = v_btb.hit[p] | v_btb.miss[p] | v_btb.alloc[p];
      v_bht.upd[p]   = v_btb.upd[p] & btac_in.upd_branch[p];
    end

    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      v_bht.sat[p] = v_btb.alloc[p] ? (btac_in.upd_jump[p] ? 2'b10 : 2'b01) :
          saturation(btac_in.upd_pred[p].tsat, btac_in.upd_jump[p]);
    end

    v_btb.wen   = 0;
    v_btb.waddr = btac_in.upd_pc[0][B_DEPTH:1];
    v_btb.wdata = 0;
    v_bht.wen   = 0;
    v_bht.waddr = btac_in.upd_pc[0][T_DEPTH:1];
    v_bht.wdata = 0;
    for (int p = ISSUE_WIDTH - 1; p >= 0; p--) begin
      if (v_btb.upd[p] == 1) begin
        v_btb.wen   = 1;
        v_btb.waddr = btac_in.upd_pc[p][B_DEPTH:1];
        v_btb.wdata = {~v_btb.kill[p], btac_in.upd_branch[p], btac_in.upd_pc[p][31:B_DEPTH+1], btac_in.upd_addr[p]};
      end
      if (v_bht.upd[p] == 1) begin
        v_bht.wen   = 1;
        v_bht.waddr = btac_in.upd_pc[p][T_DEPTH:1];
        v_bht.wdata = v_bht.sat[p];
      end
    end

    btb_in.wen   = v_btb.wen;
    btb_in.waddr = v_btb.waddr;
    btb_in.wdata = v_btb.wdata;
    bht_in.wen   = v_bht.wen;
    bht_in.waddr = v_bht.waddr;
    bht_in.wdata = v_bht.wdata;

    if (r_btb.fcount[B_DEPTH] == 0) begin
      v_btb.fcount = r_btb.fcount + 1;

      btb_in.wen   = 1;
      btb_in.waddr = r_btb.fcount[B_DEPTH-1:0];
      btb_in.wdata = 0;

      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        btac_out.pred[k].taken  = 0;
        btac_out.pred[k].tmatch = 0;
      end
    end

    rin_btb = v_btb;
    rin_bht = v_bht;

    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      btac_out.pred_maddr[p] = v_btb.maddr[p];
      btac_out.pred_miss[p]  = v_btb.miss[p];
    end

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r_btb <= init_btb_reg;
      r_bht <= init_bht_reg;
    end
    else begin
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

    end
    else begin

      typedef struct packed {
        logic [1:0][31:0] maddr;
        logic [1:0][0:0]  miss;
      } reg_type;

      localparam reg_type init_reg = '{maddr : '{default: 0}, miss : '{default: 0}};

      reg_type r, rin, v;

      always_comb begin

        v = r;

        for (int p = 0; p < 4; p++) begin
          v.maddr[p] = btac_in.upd_addr[p];
          v.miss[p]  = btac_in.upd_jump[p];
        end

        rin = v;

        for (int k = 0; k < 4; k++) begin
          btac_out.pred[k].taken  = 0;
          btac_out.pred[k].taddr  = 0;
          btac_out.pred[k].tsat   = 0;
          btac_out.pred[k].tmatch = 0;
        end
        for (int p = 0; p < 4; p++) begin
          btac_out.pred_maddr[p] = v.maddr[p];
          btac_out.pred_miss[p]  = v.miss[p];
        end

      end

      always_ff @(posedge clock) begin
        if (reset == 0) begin
          r <= init_reg;
        end
        else begin
          r <= rin;
        end
      end

    end

  endgenerate

endmodule
