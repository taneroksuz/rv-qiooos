import configure::*;
import constants::*;
import wires::*;
import functions::*;

module rs_mem (
  input  logic                           reset,
  input  logic                           clock,
  input  logic                           flush,
  input  rs_mem_in_type                  rs_in,
  input  logic           [ROB_DEPTH-1:0] rob_store_pending,
  output rs_mem_out_type                 rs_out
);
  timeunit 1ns; timeprecision 1ps;

  localparam MEM_ADDR_BITS    = $clog2(RS_MEM_DEPTH);
  localparam MEM_BANK_ENTRIES = RS_MEM_DEPTH / ISSUE_WIDTH;

  typedef struct packed {
    logic [RS_MEM_DEPTH-1:0]                       valid_bits;
    rs_entry_type [RS_MEM_DEPTH-1:0]               woken;
    rs_entry_type                                  cur_entry;
    cdb_type [RS_CDB_COUNT-1:0]                    cdb_all;
    logic [MEM_ISSUE_WIDTH-1:0][MEM_ADDR_BITS-1:0] sel_idx;
    logic [MEM_ISSUE_WIDTH-1:0]                    sel_found;
    logic [ISSUE_WIDTH-1:0][MEM_ADDR_BITS-1:0]     free_idx;
    logic [ISSUE_WIDTH-1:0]                        free_found;
    logic [RS_MEM_DEPTH-1:0]                       tag_wrap;
    logic [RS_MEM_DEPTH-1:0][RS_MEM_DEPTH-1:0]     tag_lt;
    logic [RS_MEM_DEPTH-1:0][RS_MEM_DEPTH-1:0]     lt;
    logic [RS_MEM_DEPTH-1:0]                       is_min;
    logic [RS_MEM_DEPTH-1:0]                       is_2nd;
    logic [ROB_DEPTH-1:0]                          store_wrap;
    logic [RS_MEM_DEPTH-1:0]                       older_store;
    logic [RS_MEM_DEPTH-1:0]                       ent_ready;
    logic [RS_MEM_DEPTH-1:0]                       ent_load;
    logic [MEM_ISSUE_WIDTH-1:0]                    oldest_load;
    logic [MEM_ISSUE_WIDTH-1:0][MEM_ADDR_BITS-1:0] oldest_idx;
    logic [MEM_ISSUE_WIDTH-1:0]                    oldest_found;
    logic [MEM_ISSUE_WIDTH-1:0]                    oldest_ready;
    logic [MEM_ISSUE_WIDTH-1:0]                    port_busy;
    logic [RS_MEM_DEPTH-1:0]                       slot_free;
  } rs_mem_reg_type;

  localparam rs_mem_reg_type init_rs_mem_reg = '{
      valid_bits: '0,
      woken: '{default: init_rs_entry},
      cur_entry: init_rs_entry,
      default: '0
  };

  rs_entry_type array[0:RS_MEM_DEPTH-1];

  rs_mem_reg_type r, rin, v;

  always_comb begin
    v              = r;
    rs_out         = '0;
    v.sel_idx      = '0;
    v.sel_found    = '0;
    v.free_idx     = '0;
    v.free_found   = '0;
    v.oldest_idx   = '0;
    v.oldest_found = '0;
    v.oldest_ready = '0;
    v.oldest_load  = '0;
    v.port_busy    = rs_in.load_busy;

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.cdb_all[k]                             = rs_in.cdb[k];
      v.cdb_all[ISSUE_WIDTH+MEM_ISSUE_WIDTH+k] = rs_in.cdb_commit[k];
    end
    for (int k = 0; k < MEM_ISSUE_WIDTH; k++) begin
      v.cdb_all[ISSUE_WIDTH+k] = rs_in.cdb_load[k];
    end

    for (int i = 0; i < RS_MEM_DEPTH; i++) begin
      v.cur_entry       = array[i];
      v.cur_entry.valid = r.valid_bits[i];
      v.woken[i]        = rs_wakeup_all(v.cur_entry, v.cdb_all);
      v.tag_wrap[i]     = array[i].rob_tag < rs_in.rob_head;
    end

    for (int j = 0; j < ROB_DEPTH; j++) begin
      v.store_wrap[j] = ROB_ADDR_BITS'(unsigned'(j)) < rs_in.rob_head;
    end

    for (int i = 0; i < RS_MEM_DEPTH; i++) begin
      for (int j = 0; j < RS_MEM_DEPTH; j++) begin
        v.tag_lt[i][j] = (array[i].rob_tag < array[j].rob_tag) || ((array[i].rob_tag == array[j].rob_tag) && (i < j));
        v.lt[i][j]     = (v.tag_wrap[i] == v.tag_wrap[j]) ? v.tag_lt[i][j] : v.tag_wrap[j];
      end
    end

    for (int i = 0; i < RS_MEM_DEPTH; i++) begin
      v.older_store[i] = 1'b0;
      for (int j = 0; j < ROB_DEPTH; j++) begin
        if (rob_store_pending[j] && ((v.store_wrap[j] == v.tag_wrap[i]) ?
                                     (ROB_ADDR_BITS'(unsigned'(j)) < array[i].rob_tag) : v.tag_wrap[i])) begin
          v.older_store[i] = 1'b1;
        end
      end
    end

    for (int i = 0; i < RS_MEM_DEPTH; i++) begin
      v.is_min[i] = r.valid_bits[i];
      for (int j = 0; j < RS_MEM_DEPTH; j++) begin
        if (j != i) begin
          v.is_min[i] = v.is_min[i] & (~r.valid_bits[j] | v.lt[i][j]);
        end
      end
    end

    for (int i = 0; i < RS_MEM_DEPTH; i++) begin
      v.is_2nd[i] = r.valid_bits[i] & ~v.is_min[i];
      for (int j = 0; j < RS_MEM_DEPTH; j++) begin
        if (j != i) begin
          v.is_2nd[i] = v.is_2nd[i] & (~r.valid_bits[j] | v.is_min[j] | v.lt[i][j]);
        end
      end
    end

    for (int i = 0; i < RS_MEM_DEPTH; i++) begin
      v.ent_load[i] = v.woken[i].op.load;
      v.ent_ready[i] = v.woken[i].src1_ready && v.woken[i].src2_ready &&
          (v.woken[i].op.store || (v.woken[i].op.load && !v.older_store[i]));
    end

    for (int i = 0; i < RS_MEM_DEPTH; i++) begin
      if (v.is_min[i]) begin
        v.oldest_idx[0]   = MEM_ADDR_BITS'(unsigned'(i));
        v.oldest_found[0] = 1'b1;
        v.oldest_ready[0] = v.ent_ready[i];
        v.oldest_load[0]  = v.ent_load[i];
      end
      if (v.is_2nd[i]) begin
        v.oldest_idx[1]   = MEM_ADDR_BITS'(unsigned'(i));
        v.oldest_found[1] = 1'b1;
        v.oldest_ready[1] = v.ent_ready[i];
        v.oldest_load[1]  = v.ent_load[i];
      end
    end
    v.sel_found[0] = 1'b0;
    v.sel_found[1] = 1'b0;
    if (v.oldest_found[0] && v.oldest_ready[0]) begin
      if (!v.port_busy[0]) begin
        v.sel_idx[0]   = v.oldest_idx[0];
        v.sel_found[0] = 1'b1;
      end
      else if (!v.port_busy[1]) begin
        v.sel_idx[1]   = v.oldest_idx[0];
        v.sel_found[1] = 1'b1;
      end
    end
    if (v.sel_found[0] && v.oldest_found[1] && v.oldest_ready[1]) begin
      if (!(v.oldest_load[0] ^ v.oldest_load[1])) begin
        if (!v.port_busy[1]) begin
          v.sel_idx[1]   = v.oldest_idx[1];
          v.sel_found[1] = 1'b1;
        end
      end
    end

    for (int i = 0; i < RS_MEM_DEPTH; i++) begin
      v.slot_free[i] = (!v.woken[i].valid || (v.sel_found[0] && (v.sel_idx[0] == MEM_ADDR_BITS'(unsigned'(i)))) ||
                        (v.sel_found[1] && (v.sel_idx[1] == MEM_ADDR_BITS'(unsigned'(i)))));
    end
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      for (int m = MEM_BANK_ENTRIES - 1; m >= 0; m--) begin
        if (v.slot_free[m*ISSUE_WIDTH+k]) begin
          v.free_idx[k]   = MEM_ADDR_BITS'(unsigned'(m * ISSUE_WIDTH + k));
          v.free_found[k] = 1'b1;
        end
      end
    end

    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      rs_out.issue[p]       = v.sel_found[p] ? v.woken[v.sel_idx[p]] : init_rs_entry;
      rs_out.issue_valid[p] = v.sel_found[p];
    end
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      rs_out.alloc_ok[k] = 1'b0;
      for (int m = 0; m < MEM_BANK_ENTRIES; m++) begin
        if (!r.valid_bits[m*ISSUE_WIDTH+k]) begin
          rs_out.alloc_ok[k] = 1'b1;
        end
      end
    end

    if (flush) begin
      rs_out       = '0;
      v.sel_found  = '0;
      v.free_found = '0;
      v.valid_bits = '0;
    end
    else begin
      for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
        if (v.sel_found[p]) begin
          v.valid_bits[v.sel_idx[p]] = 1'b0;
        end
      end
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (rs_in.alloc[k] && v.free_found[k]) begin
          v.valid_bits[v.free_idx[k]] = 1'b1;
        end
      end
    end
    rin = v;
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_rs_mem_reg;
    end
    else begin
      r <= rin;
    end
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      for (int i = 0; i < RS_MEM_DEPTH; i++) begin
        array[i] <= init_rs_entry;
      end
    end
    else begin
      if (!flush) begin
        for (int k = 0; k < ISSUE_WIDTH; k++) begin
          for (int m = 0; m < MEM_BANK_ENTRIES; m++) begin
            if (rs_in.alloc[k] && rin.free_found[k] &&
                (rin.free_idx[k] == MEM_ADDR_BITS'(unsigned'(m * ISSUE_WIDTH + k)))) begin
              array[m*ISSUE_WIDTH+k] <= rs_in.entry[k];
            end
            else if (r.valid_bits[m*ISSUE_WIDTH+k] && rin.valid_bits[m*ISSUE_WIDTH+k] &&
                     !(rin.sel_found[0] && (rin.sel_idx[0] == MEM_ADDR_BITS'(unsigned'(m * ISSUE_WIDTH + k)))) &&
                     !(rin.sel_found[1] && (rin.sel_idx[1] == MEM_ADDR_BITS'(unsigned'(m * ISSUE_WIDTH + k))))) begin
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
