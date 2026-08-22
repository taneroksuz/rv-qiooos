import configure::*;
import constants::*;
import wires::*;
module cpu (
  input  logic               reset,
  input  logic               clear,
  input  logic               clock,
  input  mem_out_type        imem_out[0:1],
  output mem_in_type         imem_in [0:1],
  input  mem_out_type        dmem_out[0:1],
  output mem_in_type         dmem_in [0:1],
  input  logic        [ 0:0] meip,
  input  logic        [ 0:0] msip,
  input  logic        [ 0:0] mtip,
  input  logic        [63:0] mtime
);
  timeunit 1ns; timeprecision 1ps;
  cdb_type cdb[0:ISSUE_WIDTH-1], cdb_load[0:MEM_ISSUE_WIDTH-1];
  cdb_type                          cdb_exec          [             0:1];
  cdb_type                          cdb_commit        [ 0:ISSUE_WIDTH-1];
  csr_read_in_type                  csr_rin;
  alu_in_type                       alu_in            [   0:ALU_COUNT-1];
  alu_out_type                      alu_out           [   0:ALU_COUNT-1];
  bcu_in_type                       bcu_in            [   0:BCU_COUNT-1];
  bcu_out_type                      bcu_out           [   0:BCU_COUNT-1];
  mul_in_type                       mul_in            [   0:MUL_COUNT-1];
  mul_out_type                      mul_out           [   0:MUL_COUNT-1];
  div_in_type                       div_in;
  div_out_type                      div_out;
  bit_alu_in_type                   bit_alu_in        [0:BITALU_COUNT-1];
  bit_alu_out_type                  bit_alu_out       [0:BITALU_COUNT-1];
  csr_alu_in_type                   csr_alu_in;
  csr_alu_out_type                  csr_alu_out;
  lsu_in_type                       lsu_in            [   0:LSU_COUNT-1];
  lsu_out_type                      lsu_out           [   0:LSU_COUNT-1];
  csr_out_type                      csr_out;
  agu_in_type                       agu_in            [   0:AGU_COUNT-1];
  agu_out_type                      agu_out           [   0:AGU_COUNT-1];
  btac_in_type                      btac_in;
  btac_out_type                     btac_out;
  buffer_in_type                    buffer_in;
  buffer_out_type                   buffer_out;
  compress_in_type                  compress_in       [ 0:ISSUE_WIDTH-1];
  compress_out_type                 compress_out      [ 0:ISSUE_WIDTH-1];
  base_in_type                      base_in           [ 0:ISSUE_WIDTH-1];
  base_out_type                     base_out          [ 0:ISSUE_WIDTH-1];
  fetch_in_type                     fetch_in;
  fetch_out_type                    fetch_out;
  decode_in_type                    decode_in;
  decode_out_type                   decode_out;
  prf_in_type                       prf_in;
  prf_out_type                      prf_out;
  fl_in_type                        fl_in;
  fl_out_type                       fl_out;
  rat_in_type                       rat_in;
  rat_out_type                      rat_out;
  rob_in_type                       rob_in;
  rob_out_type                      rob_out;
  rs_int_in_type                    rs_int_in;
  rs_int_out_type                   rs_int_out;
  rs_mem_in_type                    rs_mem_in;
  rs_mem_out_type                   rs_mem_out;
  rename_in_type                    rename_in;
  rename_out_type                   rename_out;
  eu_in_type                        eu_in;
  eu_out_type                       eu_out;
  msu_in_type                       msu_in;
  msu_out_type                      msu_out;
  commit_in_type                    commit_in;
  commit_out_type                   commit_out;
  cache_in_type                     cache_in;
  cache_out_type                    cache_out;
  logic             [ROB_DEPTH-1:0] rob_store_pending;
  logic             [          0:0] commit_flush;

  genvar i;

  always_comb begin
    commit_flush = clear | csr_out.trap | csr_out.mret | (|btac_out.pred_miss) | commit_out.flush;
    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      commit_flush = commit_flush | fetch_in.entry[p].fence;
    end
  end

  assign fetch_in.csr_out    = csr_out;
  assign fetch_in.btac_out   = btac_out;
  assign fetch_in.cache_out  = cache_out;
  assign fetch_in.buffer_out = buffer_out;
  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : g_fetch_entry
      assign fetch_in.entry[i] = commit_out.commit_entry[i];
    end
  endgenerate
  assign buffer_in = fetch_out.buffer_in;
  assign btac_in   = fetch_out.btac_in;
  assign cache_in  = fetch_out.cache_in;
  assign csr_rin   = rs_int_out.csr_rin;
  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : g_decode_base
      assign decode_in.base_out[i]     = base_out[i];
      assign decode_in.compress_out[i] = compress_out[i];
      assign decode_in.pc[i]           = fetch_out.pc[i];
      assign decode_in.instr[i]        = fetch_out.instr[i];
      assign decode_in.ready[i]        = fetch_out.ready[i];
      assign base_in[i]                = decode_out.base_in[i];
      assign compress_in[i]            = decode_out.compress_in[i];
    end
  endgenerate
  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : g_prf_raddr
      assign prf_in.raddr[2*i]   = rename_out.rat.rsrc_a[2*i];
      assign prf_in.raddr[2*i+1] = rename_out.rat.rsrc_a[2*i+1];
    end
  endgenerate
  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : g_prf_wport
      assign prf_in.waddr[i] = commit_out.prf_i.waddr[i];
      assign prf_in.wdata[i] = commit_out.prf_i.wdata[i];
      assign prf_in.wren[i]  = commit_out.prf_i.wren[i];
    end
  endgenerate
  generate
    for (i = 0; i < 2 * ISSUE_WIDTH; i++) begin : g_rat_rsrc
      assign rat_in.rsrc_a[i] = rename_out.rat.rsrc_a[i];
    end
  endgenerate
  generate
    for (i = 0; i < ALU_COUNT; i++) begin : g_eu_alu_in
      assign alu_in[i] = eu_out.alu_in[i];
    end
  endgenerate
  generate
    for (i = 0; i < AGU_COUNT; i++) begin : g_eu_agu_in
      assign agu_in[i] = eu_out.agu_in[i];
    end
  endgenerate
  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : g_rat_wport
      assign rat_in.waddr_a[i]            = rename_out.rat.waddr_a[i];
      assign rat_in.waddr_p[i]            = rename_out.rat.waddr_p[i];
      assign rat_in.wren[i]               = rename_out.rat.wren[i];
      assign rat_in.commit_addr[i]        = commit_out.rat_i.commit_addr[i];
      assign rat_in.commit_tag[i]         = commit_out.rat_i.commit_tag[i];
      assign rat_in.commit_valid[i]       = commit_out.rat_i.commit_valid[i];
      assign fl_in.alloc[i]               = rename_out.fl.alloc[i];
      assign fl_in.free_tag[i]            = commit_out.fl_i.free_tag[i];
      assign fl_in.free_en[i]             = commit_out.fl_i.free_en[i];
      assign rob_in.alloc[i]              = rename_out.rob_alloc[i];
      assign rob_in.alloc_entry[i]        = rename_out.rob_entry[i];
      assign rs_int_in.entry[i]           = rename_out.rs_entry[i];
      assign rs_int_in.alloc[i]           = rename_out.rs_int_alloc[i];
      assign rs_mem_in.entry[i]           = rename_out.rs_entry[i];
      assign rs_mem_in.alloc[i]           = rename_out.rs_mem_alloc[i];
      assign rename_in.instr[i]           = decode_out.instr[i];
      assign rename_in.rob_tag[i]         = rob_out.alloc_tag[i];
      assign rename_in.rob_alloc_ok[i]    = rob_out.alloc_ok[i];
      assign rename_in.rs_int_alloc_ok[i] = rs_int_out.alloc_ok[i];
      assign rename_in.rs_mem_alloc_ok[i] = rs_mem_out.alloc_ok[i];
      assign eu_in.int_issue[i]           = rs_int_out.issue[i];
      assign eu_in.int_issue_valid[i]     = rs_int_out.issue_valid[i];
    end
  endgenerate
  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : g_rob_wport_int
      assign rob_in.write_tag[i]   = eu_out.rob_wtag[i];
      assign rob_in.write_entry[i] = eu_out.rob_wentry[i];
      assign rob_in.write_en[i]    = eu_out.rob_wen[i];
    end
  endgenerate
  generate
    for (i = 0; i < MEM_ISSUE_WIDTH; i++) begin : g_rob_wport_mem
      assign rob_in.write_tag[ISSUE_WIDTH+i]                   = msu_out.rob_wtag[i];
      assign rob_in.write_entry[ISSUE_WIDTH+i]                 = msu_out.rob_wentry[i];
      assign rob_in.write_en[ISSUE_WIDTH+i]                    = msu_out.rob_wen[i];
      assign rob_in.write_tag[ISSUE_WIDTH+MEM_ISSUE_WIDTH+i]   = eu_out.rob_wtag_store[i];
      assign rob_in.write_entry[ISSUE_WIDTH+MEM_ISSUE_WIDTH+i] = eu_out.rob_wentry_store[i];
      assign rob_in.write_en[ISSUE_WIDTH+MEM_ISSUE_WIDTH+i]    = eu_out.rob_wen_store[i];
    end
  endgenerate
  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : g_cdb_fanin
      assign rs_int_in.cdb[i]        = cdb[i];
      assign rs_mem_in.cdb[i]        = cdb[i];
      assign rename_in.cdb[i]        = cdb[i];
      assign rs_int_in.cdb_commit[i] = cdb_commit[i];
      assign rs_mem_in.cdb_commit[i] = cdb_commit[i];
    end
  endgenerate
  generate
    for (i = 0; i < MEM_ISSUE_WIDTH; i++) begin : g_cdb_load_fanin
      assign rs_int_in.cdb_load[i] = cdb_load[i];
      assign rs_mem_in.cdb_load[i] = cdb_load[i];
      assign rename_in.cdb_load[i] = cdb_load[i];
    end
  endgenerate
  assign rs_int_in.div_busy   = eu_out.div_busy;
  assign rs_int_in.csr_commit = commit_out.csr_win.cwren;
  assign rs_int_in.rob_head   = rob_out.head_ptr;
  assign rs_mem_in.rob_head   = rob_out.head_ptr;
  assign rs_mem_in.load_busy  = msu_out.load_busy;
  assign rename_in.btac_out   = btac_out;
  assign rename_in.rat        = rat_out;
  assign rename_in.prf        = prf_out;
  assign rename_in.fl         = fl_out;
  generate
    for (i = 0; i < MEM_ISSUE_WIDTH; i++) begin : g_mem_issue
      assign eu_in.mem_issue[i]       = rs_mem_out.issue[i];
      assign eu_in.mem_issue_valid[i] = rs_mem_out.issue_valid[i];
    end
  endgenerate
  generate
    for (i = 0; i < BCU_COUNT; i++) begin : g_bcu_port
      assign bcu_in[i]        = eu_out.bcu_in[i];
      assign eu_in.bcu_out[i] = bcu_out[i];
    end
  endgenerate
  generate
    for (i = 0; i < MUL_COUNT; i++) begin : g_mul_port
      assign mul_in[i]        = eu_out.mul_in[i];
      assign eu_in.mul_out[i] = mul_out[i];
    end
  endgenerate
  generate
    for (i = 0; i < BITALU_COUNT; i++) begin : g_bitalu_port
      assign bit_alu_in[i]        = eu_out.bit_alu_in[i];
      assign eu_in.bit_alu_out[i] = bit_alu_out[i];
    end
  endgenerate
  assign csr_alu_in        = eu_out.csr_alu_in;
  assign eu_in.csr_alu_out = csr_alu_out;
  assign eu_in.csr         = csr_out;
  generate
    for (i = 0; i < ALU_COUNT; i++) begin : g_eu_alu_out
      assign eu_in.alu_out[i] = alu_out[i];
    end
  endgenerate
  generate
    for (i = 0; i < AGU_COUNT; i++) begin : g_eu_agu_out
      assign eu_in.agu_out[i] = agu_out[i];
    end
  endgenerate
  assign eu_in.div_out = div_out;
  assign div_in        = eu_out.div_in;
  assign cdb_exec[0]   = eu_out.cdb[0];
  assign cdb_exec[1]   = eu_out.cdb[1];
  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : g_cdb_commit_derive
      assign cdb_commit[i].valid = commit_out.prf_i.wren[i];
      assign cdb_commit[i].tag   = commit_out.rat_i.commit_tag[i];
      assign cdb_commit[i].data  = commit_out.prf_i.wdata[i];
    end
  endgenerate
  assign cdb[0] = cdb_exec[0].valid ? cdb_exec[0] : cdb_commit[0];
  assign cdb[1] = cdb_exec[1].valid ? cdb_exec[1] : cdb_commit[1];
  assign cdb[2] = eu_out.cdb[2];
  assign cdb[3] = eu_out.cdb[3];
  generate
    for (i = 0; i < MEM_ISSUE_WIDTH; i++) begin : g_msu_mem_issue
      assign msu_in.issue[i]        = eu_in.mem_issue[i];
      assign msu_in.issue_valid[i]  = eu_in.mem_issue_valid[i];
      assign msu_in.agu_out[i]      = agu_out[AGU_BRANCH_COUNT+i];
      assign msu_in.lsu_out[i]      = lsu_out[i];
      assign msu_in.dmem_out[i]     = dmem_out[i];
      assign msu_in.commit_store[i] = commit_out.store_slot_valid[i];
      assign msu_in.commit_entry[i] = commit_out.store_slot_entry[i];
      assign dmem_in[i]             = msu_out.dmem_in[i];
      assign lsu_in[i]              = msu_out.lsu_in[i];
      assign cdb_load[i]            = msu_out.cdb[i];
    end
  endgenerate
  assign commit_in.irpt = csr_out.irpt;
  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : g_commit_in
      assign commit_in.commit_valid[i] = rob_out.commit_valid[i];
      assign commit_in.entry[i]        = rob_out.entry[i];
    end
  endgenerate
  generate
    for (i = 0; i < ALU_COUNT; i++) begin : g_alu_comp
      alu alu_comp (
        .alu_in (alu_in[i]),
        .alu_out(alu_out[i])
      );
    end
  endgenerate
  generate
    for (i = 0; i < AGU_COUNT; i++) begin : g_agu_comp
      agu agu_comp (
        .agu_in (agu_in[i]),
        .agu_out(agu_out[i])
      );
    end
  endgenerate
  generate
    for (i = 0; i < BCU_COUNT; i++) begin : g_bcu_comp
      bcu bcu_comp (
        .bcu_in (bcu_in[i]),
        .bcu_out(bcu_out[i])
      );
    end
  endgenerate
  generate
    for (i = 0; i < LSU_COUNT; i++) begin : g_lsu_comp
      lsu lsu_comp (
        .lsu_in (lsu_in[i]),
        .lsu_out(lsu_out[i])
      );
    end
  endgenerate
  csr_alu csr_alu_comp (
    .csr_alu_in (csr_alu_in),
    .csr_alu_out(csr_alu_out)
  );
  generate
    for (i = 0; i < MUL_COUNT; i++) begin : g_mul_comp
      mul mul_comp (
        .reset  (reset),
        .clock  (clock),
        .mul_in (mul_in[i]),
        .mul_out(mul_out[i])
      );
    end
  endgenerate
  div div_comp (
    .reset  (reset),
    .clock  (clock),
    .flush  (commit_flush),
    .div_in (div_in),
    .div_out(div_out)
  );
  generate
    for (i = 0; i < BITALU_COUNT; i++) begin : g_bit_alu_comp
      bit_alu bit_alu_comp (
        .bit_alu_in (bit_alu_in[i]),
        .bit_alu_out(bit_alu_out[i])
      );
    end
  endgenerate
  btac btac_comp (
    .reset   (reset),
    .clock   (clock),
    .btac_in (btac_in),
    .btac_out(btac_out)
  );
  buffer buffer_comp (
    .reset     (reset),
    .clock     (clock),
    .buffer_in (buffer_in),
    .buffer_out(buffer_out)
  );
  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : g_base_comp
      base base_comp (
        .base_in (base_in[i]),
        .base_out(base_out[i])
      );
    end
  endgenerate
  generate
    for (i = 0; i < ISSUE_WIDTH; i++) begin : g_compress_comp
      compress compress_comp (
        .compress_in (compress_in[i]),
        .compress_out(compress_out[i])
      );
    end
  endgenerate
  csr csr_comp (
    .reset  (reset),
    .clock  (clock),
    .csr_rin(csr_rin),
    .csr_win(commit_out.csr_win),
    .csr_ein(commit_out.csr_ein),
    .csr_out(csr_out),
    .meip   (meip),
    .msip   (msip),
    .mtip   (mtip),
    .mtime  (mtime)
  );
  fetch fetch_comp (
    .reset    (reset),
    .clock    (clock),
    .flush    (commit_flush),
    .stall    (rename_out.stall),
    .fetch_in (fetch_in),
    .fetch_out(fetch_out)
  );
  decode decode_comp (
    .reset     (reset),
    .clock     (clock),
    .flush     (commit_flush),
    .stall     (rename_out.stall),
    .decode_in (decode_in),
    .decode_out(decode_out)
  );
  prf prf_comp (
    .reset  (reset),
    .clock  (clock),
    .prf_in (prf_in),
    .prf_out(prf_out)
  );
  rat rat_comp (
    .reset  (reset),
    .clock  (clock),
    .flush  (commit_flush),
    .rat_in (rat_in),
    .rat_out(rat_out)
  );
  fl fl_comp (
    .reset (reset),
    .clock (clock),
    .flush (commit_flush),
    .fl_in (fl_in),
    .fl_out(fl_out)
  );
  rob rob_comp (
    .reset            (reset),
    .clock            (clock),
    .flush            (commit_flush),
    .rob_in           (rob_in),
    .rob_out          (rob_out),
    .rob_store_pending(rob_store_pending)
  );
  rs_int rs_int_comp (
    .reset (reset),
    .clock (clock),
    .flush (commit_flush),
    .rs_in (rs_int_in),
    .rs_out(rs_int_out)
  );
  rs_mem rs_mem_comp (
    .reset            (reset),
    .clock            (clock),
    .flush            (commit_flush),
    .rs_in            (rs_mem_in),
    .rob_store_pending(rob_store_pending),
    .rs_out           (rs_mem_out)
  );
  rename rename_comp (
    .flush     (commit_flush),
    .rename_in (rename_in),
    .rename_out(rename_out)
  );
  eu eu_comp (
    .reset (reset),
    .clock (clock),
    .flush (commit_flush),
    .eu_in (eu_in),
    .eu_out(eu_out)
  );
  msu msu_comp (
    .reset  (reset),
    .clock  (clock),
    .flush  (commit_flush),
    .msu_in (msu_in),
    .msu_out(msu_out)
  );
  commit commit_comp (
    .reset     (reset),
    .clock     (clock),
    .flush     (commit_flush),
    .commit_in (commit_in),
    .commit_out(commit_out)
  );
  cache cache_comp (
    .reset    (reset),
    .clock    (clock),
    .cache_in (cache_in),
    .cache_out(cache_out),
    .mem_in   (imem_in),
    .mem_out  (imem_out)
  );
endmodule
