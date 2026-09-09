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

  typedef struct packed {
    logic [RS_INT_DEPTH-1:0]                      valid_bits;
    logic [ISSUE_WIDTH-1:0][RS_ADDR_BITS-1:0]     sel_idx;
    logic [ISSUE_WIDTH-1:0]                       sel_found;
    logic [ISSUE_WIDTH-1:0][RS_ADDR_BITS-1:0]     cand_idx;
    logic [ISSUE_WIDTH-1:0]                       cand_found;
    logic [ISSUE_WIDTH-1:0]                       free_found;
    logic [RS_INT_DEPTH-1:0][RS_INT_CNT_BITS-1:0] free_rank;
    logic [ROB_CNT_BITS-1:0]                      csr_inflight;
    logic [0:0]                                   csr_drain;
    rs_int_out_type                               rs_o;
    rs_entry_type [RS_INT_DEPTH-1:0]              view;
    rs_entry_type [RS_INT_DEPTH-1:0]              woken;
    logic [RS_INT_DEPTH-1:0]                      ready_vec;
    logic [RS_INT_DEPTH-1:0]                      tag_wrap;
    logic [RS_INT_DEPTH-1:0][RS_INT_DEPTH-1:0]    tag_lt;
    logic [RS_INT_DEPTH-1:0][RS_INT_DEPTH-1:0]    lt;
    logic [RS_INT_DEPTH-1:0][RS_INT_CNT_BITS-1:0] older_cnt;
    logic [RS_INT_DEPTH-1:0]                      is_cand;
    logic [RS_INT_DEPTH-1:0]                      cls_mul;
    logic [RS_INT_DEPTH-1:0]                      cls_div;
    logic [RS_INT_DEPTH-1:0]                      cls_bit;
    logic [RS_INT_DEPTH-1:0]                      cls_csr;
    logic [RS_INT_DEPTH-1:0]                      cls_agu;
    logic [ISSUE_WIDTH-1:0]                       cand_mul;
    logic [ISSUE_WIDTH-1:0]                       cand_div;
    logic [ISSUE_WIDTH-1:0]                       cand_bit;
    logic [ISSUE_WIDTH-1:0]                       cand_csr;
    logic [ISSUE_WIDTH-1:0]                       cand_agu;
    logic [ISSUE_WIDTH-1:0][ISSUE_CNT_BITS-1:0]   pre_mul;
    logic [ISSUE_WIDTH-1:0][ISSUE_CNT_BITS-1:0]   pre_div;
    logic [ISSUE_WIDTH-1:0][ISSUE_CNT_BITS-1:0]   pre_bit;
    logic [ISSUE_WIDTH-1:0][ISSUE_CNT_BITS-1:0]   pre_csr;
    logic [ISSUE_WIDTH-1:0][ISSUE_CNT_BITS-1:0]   pre_agu;
    logic [ISSUE_WIDTH-1:0][ISSUE_CNT_BITS-1:0]   acc_prev;
    logic [ISSUE_WIDTH-1:0]                       issue_ok;
    logic [ISSUE_WIDTH-1:0][RS_ADDR_BITS-1:0]     lane_src;
    logic [ISSUE_WIDTH-1:0]                       lane_sel;
    logic [ISSUE_WIDTH-1:0][ISSUE_CNT_BITS-1:0]   lane_rank;
    logic [ISSUE_CNT_BITS-1:0]                    lane_avail_cnt;
    cdb_type [RS_CDB_COUNT-1:0]                   cdb_all;
    rs_entry_type [ISSUE_WIDTH-1:0]               issue_arr;
    logic [RS_INT_DEPTH-1:0]                      slot_free;
    logic [RS_INT_DEPTH-1:0]                      slot_issued;
    logic [RS_INT_CNT_BITS-1:0]                   free_cnt;
    logic [ISSUE_WIDTH-1:0][ISSUE_ADDR_BITS-1:0]  alloc_rank;
    logic [ISSUE_WIDTH-1:0]                       alloc_en;
    logic [RS_INT_CNT_BITS-1:0]                   inv_cnt;
    logic [RS_INT_DEPTH-1:0]                      slot_wr;
    logic [RS_INT_DEPTH-1:0][ISSUE_ADDR_BITS-1:0] slot_src;
  } rs_int_reg_type;

  localparam rs_int_out_type init_rs_int_out = '0;

  localparam rs_int_reg_type init_rs_int_reg = '{
      valid_bits: '0,
      sel_idx: '0,
      sel_found: '0,
      cand_idx: '0,
      cand_found: '0,
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
    v.free_found = '0;
    v.rs_o       = init_rs_int_out;

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.cdb_all[k] = rs_in.cdb[k];
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

      v.tag_wrap[i] = array[i].rob_tag < rs_in.rob_head;
    end

    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      v.tag_lt[i][i] = 1'b0;
      v.lt[i][i]     = 1'b0;
      for (int j = i + 1; j < RS_INT_DEPTH; j++) begin
        v.tag_lt[i][j] = array[i].rob_tag <= array[j].rob_tag;
        v.lt[i][j]     = (v.tag_wrap[i] == v.tag_wrap[j]) ? v.tag_lt[i][j] : v.tag_wrap[j];
        v.tag_lt[j][i] = ~v.tag_lt[i][j];
        v.lt[j][i]     = ~v.lt[i][j];
      end
    end

    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      v.older_cnt[i] = '0;
      for (int j = 0; j < RS_INT_DEPTH; j++) begin
        if ((j != i) && v.ready_vec[j] && v.lt[j][i]) begin
          v.older_cnt[i] = v.older_cnt[i] + RS_INT_CNT_BITS'(1);
        end
      end
      v.is_cand[i] = v.ready_vec[i] & (v.older_cnt[i] < RS_INT_CNT_BITS'(ISSUE_WIDTH));
    end

    v.cand_idx   = '0;
    v.cand_found = '0;
    v.cand_mul   = '0;
    v.cand_div   = '0;
    v.cand_bit   = '0;
    v.cand_csr   = '0;
    v.cand_agu   = '0;
    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      if (v.is_cand[i]) begin
        v.cand_idx[ISSUE_ADDR_BITS'(v.older_cnt[i])]   = RS_ADDR_BITS'(unsigned'(i));
        v.cand_found[ISSUE_ADDR_BITS'(v.older_cnt[i])] = 1'b1;
        v.cand_mul[ISSUE_ADDR_BITS'(v.older_cnt[i])]   = v.cls_mul[i];
        v.cand_div[ISSUE_ADDR_BITS'(v.older_cnt[i])]   = v.cls_div[i];
        v.cand_bit[ISSUE_ADDR_BITS'(v.older_cnt[i])]   = v.cls_bit[i];
        v.cand_csr[ISSUE_ADDR_BITS'(v.older_cnt[i])]   = v.cls_csr[i];
        v.cand_agu[ISSUE_ADDR_BITS'(v.older_cnt[i])]   = v.cls_agu[i];
      end
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.pre_mul[k] = '0;
      v.pre_div[k] = '0;
      v.pre_bit[k] = '0;
      v.pre_csr[k] = '0;
      v.pre_agu[k] = '0;
      for (int j = 0; j < k; j++) begin
        if (v.cand_found[j]) begin
          if (v.cand_mul[j]) v.pre_mul[k] = v.pre_mul[k] + ISSUE_CNT_BITS'(1);
          if (v.cand_div[j]) v.pre_div[k] = v.pre_div[k] + ISSUE_CNT_BITS'(1);
          if (v.cand_bit[j]) v.pre_bit[k] = v.pre_bit[k] + ISSUE_CNT_BITS'(1);
          if (v.cand_csr[j]) v.pre_csr[k] = v.pre_csr[k] + ISSUE_CNT_BITS'(1);
          if (v.cand_agu[j]) v.pre_agu[k] = v.pre_agu[k] + ISSUE_CNT_BITS'(1);
        end
      end
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.sel_idx[k] = v.cand_idx[k];
      if (v.cand_mul[k]) v.sel_found[k] = v.cand_found[k] & (v.pre_mul[k] < ISSUE_CNT_BITS'(MUL_COUNT));
      else if (v.cand_div[k]) v.sel_found[k] = v.cand_found[k] & (v.pre_div[k] < ISSUE_CNT_BITS'(DIV_COUNT));
      else if (v.cand_bit[k]) v.sel_found[k] = v.cand_found[k] & (v.pre_bit[k] < ISSUE_CNT_BITS'(BITALU_COUNT));
      else if (v.cand_csr[k]) v.sel_found[k] = v.cand_found[k] & (v.pre_csr[k] < ISSUE_CNT_BITS'(CSR_ALU_COUNT));
      else if (v.cand_agu[k]) v.sel_found[k] = v.cand_found[k] & (v.pre_agu[k] < ISSUE_CNT_BITS'(AGU_BRANCH_COUNT));
      else v.sel_found[k] = v.cand_found[k];
    end

    v.lane_avail_cnt = '0;
    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      v.lane_rank[l] = v.lane_avail_cnt;
      if (!rs_in.lane_block[l]) begin
        v.lane_avail_cnt = v.lane_avail_cnt + ISSUE_CNT_BITS'(1);
      end
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.acc_prev[k] = '0;
      for (int j = 0; j < k; j++) begin
        if (v.sel_found[j]) begin
          v.acc_prev[k] = v.acc_prev[k] + ISSUE_CNT_BITS'(1);
        end
      end
      v.issue_ok[k] = v.sel_found[k] & (v.acc_prev[k] < v.lane_avail_cnt);
    end

    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      v.slot_issued[i] = 1'b0;
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (v.issue_ok[k] && (v.sel_idx[k] == RS_ADDR_BITS'(unsigned'(i)))) begin
          v.slot_issued[i] = 1'b1;
        end
      end
    end

    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      v.slot_free[i] = ~v.woken[i].valid | v.slot_issued[i];
    end

    v.free_cnt = '0;
    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      v.free_rank[i] = v.free_cnt;
      if (v.slot_free[i]) begin
        v.free_cnt = v.free_cnt + RS_INT_CNT_BITS'(1);
      end
    end
    for (int c = 0; c < ISSUE_WIDTH; c++) begin
      v.free_found[c] = v.free_cnt > RS_INT_CNT_BITS'(unsigned'(c));
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.alloc_rank[k] = '0;
      for (int j = 0; j < k; j++) begin
        if (rs_in.alloc[j]) begin
          v.alloc_rank[k] = v.alloc_rank[k] + ISSUE_ADDR_BITS'(1);
        end
      end
      v.alloc_en[k] = rs_in.alloc[k] & v.free_found[v.alloc_rank[k]];
    end

    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      v.slot_wr[i]  = 1'b0;
      v.slot_src[i] = '0;
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (v.alloc_en[k] && v.slot_free[i] && (v.free_rank[i] == RS_INT_CNT_BITS'(v.alloc_rank[k]))) begin
          v.slot_wr[i]  = 1'b1;
          v.slot_src[i] = ISSUE_ADDR_BITS'(unsigned'(k));
        end
      end
    end

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      v.lane_src[l] = '0;
      v.lane_sel[l] = 1'b0;
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (v.issue_ok[k] && !rs_in.lane_block[l] && (v.lane_rank[l] == v.acc_prev[k])) begin
          v.lane_src[l] = v.sel_idx[k];
          v.lane_sel[l] = 1'b1;
        end
      end
      v.issue_arr[l]        = v.lane_sel[l] ? v.woken[v.lane_src[l]] : init_rs_entry;
      v.rs_o.issue_valid[l] = v.lane_sel[l];
      v.rs_o.issue[l]       = v.issue_arr[l];
    end

    v.inv_cnt = '0;
    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      if (!r.valid_bits[i]) begin
        v.inv_cnt = v.inv_cnt + RS_INT_CNT_BITS'(1);
      end
    end
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.rs_o.alloc_ok[k] = (v.inv_cnt > RS_INT_CNT_BITS'(unsigned'(k)));
    end

    v.rs_o.csr_rin = '0;
    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      if (v.rs_o.issue_valid[l] && v.issue_arr[l].op.csreg) begin
        v.rs_o.csr_rin.crden  = 1'b1;
        v.rs_o.csr_rin.craddr = v.issue_arr[l].caddr;
      end
    end

    if (flush) begin
      v.valid_bits  = '0;
      v.sel_found   = '0;
      v.issue_ok    = '0;
      v.free_found  = '0;
      v.alloc_en    = '0;
      v.slot_wr     = '0;
      v.slot_issued = '0;
      v.rs_o        = init_rs_int_out;
    end
    else begin
      for (int i = 0; i < RS_INT_DEPTH; i++) begin
        if (v.slot_issued[i]) begin
          v.valid_bits[i] = 1'b0;
        end
        if (v.slot_wr[i]) begin
          v.valid_bits[i] = 1'b1;
        end
      end
      v.csr_drain = 1'b0;
      for (int l = 0; l < ISSUE_WIDTH; l++) begin
        if (v.rs_o.issue_valid[l] && v.issue_arr[l].op.csreg && v.issue_arr[l].op.cwren) begin
          v.csr_inflight = v.csr_inflight + ROB_CNT_BITS'(1);
        end
      end
      if (rs_in.csr_commit && v.csr_inflight > 0) begin
        if (v.csr_inflight == ROB_CNT_BITS'(1)) begin
          v.csr_drain = 1'b1;
        end
        v.csr_inflight = v.csr_inflight - ROB_CNT_BITS'(1);
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
        for (int i = 0; i < RS_INT_DEPTH; i++) begin
          if (rin.slot_wr[i]) begin
            array[i] <= rs_in.entry[rin.slot_src[i]];
          end
          else if (r.valid_bits[i] && rin.valid_bits[i] && !rin.slot_issued[i]) begin
            array[i].src1_ready <= rin.woken[i].src1_ready;
            array[i].src2_ready <= rin.woken[i].src2_ready;
            array[i].rdata1     <= rin.woken[i].rdata1;
            array[i].rdata2     <= rin.woken[i].rdata2;
          end
        end
      end
    end
  end

endmodule
