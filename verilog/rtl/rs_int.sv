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
    logic [RS_ADDR_BITS:0]                    count;
    logic [RS_INT_DEPTH-1:0]                  valid_bits;
    logic [ISSUE_WIDTH-1:0][RS_ADDR_BITS-1:0] sel_idx;
    logic [ISSUE_WIDTH-1:0]                   sel_found;
    logic [ISSUE_WIDTH-1:0][RS_ADDR_BITS-1:0] free_idx;
    logic [ISSUE_WIDTH-1:0]                   free_found;
    logic [3:0]                               csr_inflight;
    logic [0:0]                               csr_drain;
    rs_int_out_type                           rs_o;
    rs_entry_type [RS_INT_DEPTH-1:0]          view;
    rs_entry_type [RS_INT_DEPTH-1:0]          woken;
    logic [RS_INT_DEPTH-1:0]                  ready_vec;
    cdb_type [RS_CDB_COUNT-1:0]               cdb_all;
    rs_entry_type [ISSUE_WIDTH-1:0]           issue_arr;
    logic [2:0]                               mul_budget;
    logic [2:0]                               div_budget;
    logic [2:0]                               agu_budget;
    logic [2:0]                               bcu_budget;
    logic [2:0]                               bitalu_budget;
    logic [2:0]                               csralu_budget;
    logic [2:0]                               sel_count;
    logic [0:0]                               csr_taken;
    logic [0:0]                               needs_bcu;
    logic [0:0]                               needs_agu;
    logic [0:0]                               can_take;
    logic [RS_INT_DEPTH-1:0]                  slot_free;
    logic [RS_INT_DEPTH-1:0]                  slot_issued;
  } rs_int_reg_type;

  localparam rs_int_out_type init_rs_int_out = '0;

  localparam rs_int_reg_type init_rs_int_reg = '{
      count: '0,
      valid_bits: '0,
      sel_idx: '0,
      sel_found: '0,
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
    end

    v.mul_budget    = MUL_COUNT;
    v.div_budget    = DIV_COUNT;
    v.agu_budget    = AGU_BRANCH_COUNT;
    v.bcu_budget    = BCU_COUNT;
    v.bitalu_budget = BITALU_COUNT;
    v.csralu_budget = CSR_ALU_COUNT;
    v.sel_count     = 0;
    v.csr_taken     = 1'b0;

    for (int i = RS_INT_DEPTH - 1; i >= 0; i--) begin
      v.needs_bcu = v.woken[i].op.branch;
      v.needs_agu = v.woken[i].op.auipc | v.woken[i].op.jal | v.woken[i].op.jalr | v.woken[i].op.branch;

      if (v.woken[i].op.mult) v.can_take = (v.mul_budget > 0);
      else if (v.woken[i].op.division) v.can_take = (v.div_budget > 0);
      else if (v.woken[i].op.bitm) v.can_take = (v.bitalu_budget > 0);
      else if (v.woken[i].op.csreg) v.can_take = (v.csralu_budget > 0);
      else if (v.needs_bcu) v.can_take = (v.agu_budget > 0) && (v.bcu_budget > 0);
      else if (v.needs_agu) v.can_take = (v.agu_budget > 0);
      else v.can_take = 1'b1;

      if (v.ready_vec[i] && (v.sel_count < ISSUE_WIDTH) && !v.csr_taken) begin
        if (v.can_take) begin
          v.sel_idx[ISSUE_ADDR_BITS'(v.sel_count)]   = RS_ADDR_BITS'(unsigned'(i));
          v.sel_found[ISSUE_ADDR_BITS'(v.sel_count)] = 1'b1;
          v.sel_count                                = v.sel_count + 1;

          if (v.woken[i].op.mult) v.mul_budget = v.mul_budget - 1;
          else if (v.woken[i].op.division) v.div_budget = v.div_budget - 1;
          else if (v.woken[i].op.bitm) v.bitalu_budget = v.bitalu_budget - 1;
          else if (v.woken[i].op.csreg) begin
            v.csralu_budget = v.csralu_budget - 1;
            v.csr_taken     = 1'b1;
          end
          else if (v.needs_bcu) begin
            v.agu_budget = v.agu_budget - 1;
            v.bcu_budget = v.bcu_budget - 1;
          end
          else if (v.needs_agu) begin
            v.agu_budget = v.agu_budget - 1;
          end
        end
      end
    end

    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      v.slot_free[i] = ~v.woken[i].valid;
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (v.sel_found[k] && (v.sel_idx[k] == RS_ADDR_BITS'(unsigned'(i)))) begin
          v.slot_free[i] = 1'b1;
        end
      end
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
      v.count      = '0;
      v.valid_bits = '0;
      v.sel_found  = '0;
      v.free_found = '0;
      v.rs_o       = init_rs_int_out;
    end
    else begin
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (v.sel_found[k]) begin
          v.valid_bits[v.sel_idx[k]] = 1'b0;
          v.count                    = v.count - 1'b1;
        end
      end
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (rs_in.alloc[k] && v.free_found[k]) begin
          v.valid_bits[v.free_idx[k]] = 1'b1;
          v.count                     = v.count + 1'b1;
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

    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      v.slot_issued[i] = 1'b0;
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (v.sel_found[k] && (v.sel_idx[k] == RS_ADDR_BITS'(unsigned'(i)))) begin
          v.slot_issued[i] = 1'b1;
        end
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
