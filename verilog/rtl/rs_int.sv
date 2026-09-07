import configure::*;
import constants::*;
import wires::*;
import functions::*;

module rs_int (
  input  logic           reset,
  input  logic           clock,
  input  logic           flush,
  input  rs_int_in_type  rs_in,
  output rs_int_out_type rs_out
);
  timeunit 1ns; timeprecision 1ps;

  localparam RS_BANK_ENTRIES = RS_INT_DEPTH / ISSUE_WIDTH;

  typedef struct packed {
    logic [RS_INT_DEPTH-1:0]                  valid_bits;
    logic [ISSUE_WIDTH-1:0][RS_ADDR_BITS-1:0] sel_idx;
    logic [ISSUE_WIDTH-1:0]                   sel_found;
    logic [ISSUE_WIDTH-1:0][RS_ADDR_BITS-1:0] cand_idx;
    logic [ISSUE_WIDTH-1:0]                   cand_found;
    logic [ISSUE_WIDTH-1:0][RS_ADDR_BITS-1:0] free_idx;
    logic [ISSUE_WIDTH-1:0]                   free_found;
    logic [3:0]                               csr_inflight;
    logic [0:0]                               csr_drain;
    rs_int_out_type                           rs_o;
    rs_entry_type [RS_INT_DEPTH-1:0]          view;
    rs_entry_type [RS_INT_DEPTH-1:0]          woken;
    logic [RS_INT_DEPTH-1:0]                  ready_vec;
    logic [RS_INT_DEPTH-1:0]                  cls_mul;
    logic [RS_INT_DEPTH-1:0]                  cls_div;
    logic [RS_INT_DEPTH-1:0]                  cls_bit;
    logic [RS_INT_DEPTH-1:0]                  cls_csr;
    logic [RS_INT_DEPTH-1:0]                  cls_agu;
    logic [ISSUE_WIDTH-1:0]                   cand_mul;
    logic [ISSUE_WIDTH-1:0]                   cand_div;
    logic [ISSUE_WIDTH-1:0]                   cand_bit;
    logic [ISSUE_WIDTH-1:0]                   cand_csr;
    logic [ISSUE_WIDTH-1:0]                   cand_agu;
    logic [ISSUE_WIDTH-1:0][2:0]              pre_mul;
    logic [ISSUE_WIDTH-1:0][2:0]              pre_div;
    logic [ISSUE_WIDTH-1:0][2:0]              pre_bit;
    logic [ISSUE_WIDTH-1:0][2:0]              pre_csr;
    logic [ISSUE_WIDTH-1:0][2:0]              pre_agu;
    cdb_type [RS_CDB_COUNT-1:0]               cdb_all;
    rs_entry_type [ISSUE_WIDTH-1:0]           issue_arr;
    logic [RS_INT_DEPTH-1:0]                  slot_free;
    logic [RS_INT_DEPTH-1:0]                  slot_issued;
  } rs_int_reg_type;

  localparam rs_int_out_type init_rs_int_out = '0;

  localparam rs_int_reg_type init_rs_int_reg = '{
      valid_bits: '0,
      sel_idx: '0,
      sel_found: '0,
      cand_idx: '0,
      cand_found: '0,
      free_idx: '0,
      free_found: '0,
      csr_inflight: '0,
      csr_drain: 1'b0,
      rs_o: init_rs_int_out,
      view: '{default: init_rs_entry},
      woken: '{default: init_rs_entry},
      issue_arr: '{default: init_rs_entry},
      default: '0
  };

  rs_entry_type array[0:RS_INT_DEPTH-1];

  rs_int_reg_type r, rin, v;

  always_comb begin
    v            = r;
    v.sel_idx    = '0;
    v.sel_found  = '0;
    v.free_idx   = '0;
    v.free_found = '0;
    v.rs_o       = init_rs_int_out;

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.cdb_all[k]                             = rs_in.cdb[k];
      v.cdb_all[ISSUE_WIDTH+MEM_ISSUE_WIDTH+k] = rs_in.cdb_commit[k];
    end
    for (int k = 0; k < MEM_ISSUE_WIDTH; k++) begin
      v.cdb_all[ISSUE_WIDTH+k] = rs_in.cdb_load[k];
    end

    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      v.view[i] = array[i];
      v.view[i].valid = r.valid_bits[i];
      v.woken[i] = rs_wakeup_all(v.view[i], v.cdb_all);
      v.ready_vec[i] = v.woken[i].valid & v.woken[i].src1_ready &
          v.woken[i].src2_ready & ~rs_in.div_busy & ~(v.woken[i].op.csreg & (r.csr_inflight > 0)) & ~(
          v.woken[i].op.csreg & r.csr_drain) & ~(v.woken[i].op.csreg & (v.woken[i].rob_tag != rs_in.rob_head));

      v.cls_mul[i] = array[i].op.mult;
      v.cls_div[i] = array[i].op.division & ~array[i].op.mult;
      v.cls_bit[i] = array[i].op.bitm & ~array[i].op.mult & ~array[i].op.division;
      v.cls_csr[i] = array[i].op.csreg & ~array[i].op.mult & ~array[i].op.division & ~array[i].op.bitm;
      v.cls_agu[i] = (array[i].op.auipc | array[i].op.jal | array[i].op.jalr | array[i].op.branch) & ~array[i].op.mult
          & ~array[i].op.division & ~array[i].op.bitm & ~array[i].op.csreg;
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.cand_idx[k]   = RS_ADDR_BITS'(unsigned'(k));
      v.cand_found[k] = 1'b0;
      for (int m = RS_BANK_ENTRIES - 1; m >= 0; m--) begin
        if (v.ready_vec[m*ISSUE_WIDTH+k] && !rs_in.lane_block[k]) begin
          v.cand_idx[k]   = RS_ADDR_BITS'(unsigned'(m * ISSUE_WIDTH + k));
          v.cand_found[k] = 1'b1;
        end
      end
      v.cand_mul[k] = v.cls_mul[v.cand_idx[k]];
      v.cand_div[k] = v.cls_div[v.cand_idx[k]];
      v.cand_bit[k] = v.cls_bit[v.cand_idx[k]];
      v.cand_csr[k] = v.cls_csr[v.cand_idx[k]];
      v.cand_agu[k] = v.cls_agu[v.cand_idx[k]];
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.pre_mul[k] = 3'b0;
      v.pre_div[k] = 3'b0;
      v.pre_bit[k] = 3'b0;
      v.pre_csr[k] = 3'b0;
      v.pre_agu[k] = 3'b0;
      for (int j = 0; j < k; j++) begin
        if (v.cand_found[j]) begin
          if (v.cand_mul[j]) v.pre_mul[k] = v.pre_mul[k] + 3'b1;
          if (v.cand_div[j]) v.pre_div[k] = v.pre_div[k] + 3'b1;
          if (v.cand_bit[j]) v.pre_bit[k] = v.pre_bit[k] + 3'b1;
          if (v.cand_csr[j]) v.pre_csr[k] = v.pre_csr[k] + 3'b1;
          if (v.cand_agu[j]) v.pre_agu[k] = v.pre_agu[k] + 3'b1;
        end
      end
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.sel_idx[k] = v.cand_idx[k];
      if (v.cand_mul[k]) v.sel_found[k] = v.cand_found[k] & (v.pre_mul[k] < 3'(MUL_COUNT));
      else if (v.cand_div[k]) v.sel_found[k] = v.cand_found[k] & (v.pre_div[k] < 3'(DIV_COUNT));
      else if (v.cand_bit[k]) v.sel_found[k] = v.cand_found[k] & (v.pre_bit[k] < 3'(BITALU_COUNT));
      else if (v.cand_csr[k]) v.sel_found[k] = v.cand_found[k] & (v.pre_csr[k] < 3'(CSR_ALU_COUNT));
      else if (v.cand_agu[k]) v.sel_found[k] = v.cand_found[k] & (v.pre_agu[k] < 3'(AGU_BRANCH_COUNT));
      else v.sel_found[k] = v.cand_found[k];
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      for (int m = 0; m < RS_BANK_ENTRIES; m++) begin
        v.slot_issued[m*ISSUE_WIDTH+k] = v.sel_found[k] &&
            (v.sel_idx[k] == RS_ADDR_BITS'(unsigned'(m * ISSUE_WIDTH + k)));
      end
    end

    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      v.slot_free[i] = ~v.woken[i].valid | v.slot_issued[i];
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      for (int m = RS_BANK_ENTRIES - 1; m >= 0; m--) begin
        if (v.slot_free[m*ISSUE_WIDTH+k]) begin
          v.free_idx[k]   = RS_ADDR_BITS'(unsigned'(m * ISSUE_WIDTH + k));
          v.free_found[k] = 1'b1;
        end
      end
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.issue_arr[k]        = v.sel_found[k] ? v.woken[v.sel_idx[k]] : init_rs_entry;
      v.rs_o.issue[k]       = v.issue_arr[k];
      v.rs_o.issue_valid[k] = v.sel_found[k];
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.rs_o.alloc_ok[k] = 1'b0;
      for (int m = 0; m < RS_BANK_ENTRIES; m++) begin
        if (!r.valid_bits[m*ISSUE_WIDTH+k]) begin
          v.rs_o.alloc_ok[k] = 1'b1;
        end
      end
    end

    v.rs_o.csr_rin = '0;
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      if (v.sel_found[k] && v.issue_arr[k].op.csreg) begin
        v.rs_o.csr_rin.crden  = 1'b1;
        v.rs_o.csr_rin.craddr = v.issue_arr[k].caddr;
      end
    end

    if (flush) begin
      v.valid_bits  = '0;
      v.sel_found   = '0;
      v.free_found  = '0;
      v.slot_issued = '0;
      v.rs_o        = init_rs_int_out;
    end
    else begin
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (v.sel_found[k]) begin
          v.valid_bits[v.sel_idx[k]] = 1'b0;
        end
      end
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (rs_in.alloc[k] && v.free_found[k]) begin
          v.valid_bits[v.free_idx[k]] = 1'b1;
        end
      end
      v.csr_drain = 1'b0;
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (v.sel_found[k] && v.issue_arr[k].op.csreg && v.issue_arr[k].op.cwren) begin
          v.csr_inflight = v.csr_inflight + 4'b1;
        end
      end
      if (rs_in.csr_commit && v.csr_inflight > 0) begin
        if (v.csr_inflight == 4'b1) begin
          v.csr_drain = 1'b1;
        end
        v.csr_inflight = v.csr_inflight - 4'b1;
      end
    end

    rin    = v;
    rs_out = rin.rs_o;
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_rs_int_reg;
    end
    else begin
      r <= rin;
    end
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      for (int i = 0; i < RS_INT_DEPTH; i++) begin
        array[i] <= init_rs_entry;
      end
    end
    else begin
      if (!flush) begin
        for (int k = 0; k < ISSUE_WIDTH; k++) begin
          for (int m = 0; m < RS_BANK_ENTRIES; m++) begin
            if (rs_in.alloc[k] && rin.free_found[k] &&
                (rin.free_idx[k] == RS_ADDR_BITS'(unsigned'(m * ISSUE_WIDTH + k)))) begin
              array[m*ISSUE_WIDTH+k] <= rs_in.entry[k];
            end
            else if (r.valid_bits[m*ISSUE_WIDTH+k] && rin.valid_bits[m*ISSUE_WIDTH+k] &&
                     !rin.slot_issued[m*ISSUE_WIDTH+k]) begin
              array[m*ISSUE_WIDTH+k].src1_ready <= rin.woken[m*ISSUE_WIDTH+k].src1_ready;
              array[m*ISSUE_WIDTH+k].src2_ready <= rin.woken[m*ISSUE_WIDTH+k].src2_ready;
              array[m*ISSUE_WIDTH+k].rdata1     <= rin.woken[m*ISSUE_WIDTH+k].rdata1;
              array[m*ISSUE_WIDTH+k].rdata2     <= rin.woken[m*ISSUE_WIDTH+k].rdata2;
            end
          end
        end
      end
    end
  end

endmodule
