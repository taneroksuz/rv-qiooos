package functions;
  timeunit 1ns; timeprecision 1ps;
  import configure::*;
  import wires::*;
  localparam RS_CDB_COUNT = ISSUE_WIDTH + MEM_ISSUE_WIDTH;
  function automatic [31:0] multiplexer;
    input [31:0] data0;
    input [31:0] data1;
    input [0:0] sel;
    begin
      if (sel == 0) multiplexer = data0;
      else multiplexer = data1;
    end
  endfunction
  function automatic [31:0] store_data;
    input [31:0] sdata;
    input [0:0] sb;
    input [0:0] sh;
    input [0:0] sw;
    begin
      if (sb == 1) store_data = {sdata[7:0], sdata[7:0], sdata[7:0], sdata[7:0]};
      else if (sh == 1) store_data = {sdata[15:0], sdata[15:0]};
      else if (sw == 1) store_data = sdata;
      else store_data = 0;
    end
  endfunction
  function automatic [31:0] bit_andn;
    input [31:0] rs1;
    input [31:0] rs2;
    begin
      bit_andn = rs1 & ~rs2;
    end
  endfunction
  function automatic [31:0] bit_orn;
    input [31:0] rs1;
    input [31:0] rs2;
    begin
      bit_orn = rs1 | ~rs2;
    end
  endfunction
  function automatic [31:0] bit_xnor;
    input [31:0] rs1;
    input [31:0] rs2;
    begin
      bit_xnor = ~(rs1 ^ rs2);
    end
  endfunction
  function automatic [31:0] bit_zexth;
    input [31:0] rs1;
    begin
      bit_zexth = {16'h0, rs1[15:0]};
    end
  endfunction
  function automatic [31:0] bit_sextb;
    input [31:0] rs1;
    begin
      bit_sextb = {{24{rs1[7]}}, rs1[7:0]};
    end
  endfunction
  function automatic [31:0] bit_sexth;
    input [31:0] rs1;
    begin
      bit_sexth = {{16{rs1[15]}}, rs1[15:0]};
    end
  endfunction
  function automatic [31:0] bit_ctz;
    input [31:0] rs1;
    logic [5:0] res;
    begin
      res = 6'd32;
      for (int i = 31; i >= 0; i = i - 1) begin
        if (rs1[i] == 1) res = 6'(i);
      end
      bit_ctz = {26'h0, res};
    end
  endfunction
  function automatic [31:0] bit_cpop;
    input [31:0] rs1;
    logic [1:0] l1 [0:15];
    logic [2:0] l2 [ 0:7];
    logic [3:0] l3 [ 0:3];
    logic [4:0] l4 [ 0:1];
    logic [5:0] l5;
    begin
      for (int i = 0; i < 16; i = i + 1) l1[i] = 2'(rs1[2*i]) + 2'(rs1[2*i+1]);
      for (int i = 0; i < 8; i = i + 1) l2[i] = 3'(l1[2*i]) + 3'(l1[2*i+1]);
      for (int i = 0; i < 4; i = i + 1) l3[i] = 4'(l2[2*i]) + 4'(l2[2*i+1]);
      for (int i = 0; i < 2; i = i + 1) l4[i] = 5'(l3[2*i]) + 5'(l3[2*i+1]);
      l5       = 6'(l4[0]) + 6'(l4[1]);
      bit_cpop = {26'h0, l5};
    end
  endfunction
  function automatic [31:0] bit_minmax;
    input [31:0] rs1;
    input [31:0] rs2;
    input [1:0] op;
    logic [32:0] r1, r2;
    logic [0:0] lt;
    begin
      r1 = {op[0] ? 1'b0 : rs1[31], rs1};
      r2 = {op[0] ? 1'b0 : rs2[31], rs2};
      lt = $signed(r1) < $signed(r2);
      if (lt ^ op[1]) bit_minmax = rs2;
      else bit_minmax = rs1;
    end
  endfunction
  function automatic [31:0] bit_orcb;
    input [31:0] rs1;
    logic [31:0] res;
    begin
      res = 0;
      for (int i = 0; i < 32; i = i + 8) if (|(rs1[i+:8]) == 1) res[i+:8] = 8'hFF;
      bit_orcb = res;
    end
  endfunction
  function automatic [31:0] bit_rev8;
    input [31:0] rs1;
    logic [31:0] res;
    begin
      res = 0;
      for (int i = 0; i < 32; i = i + 8) res[i+:8] = rs1[(24-i)+:8];
      bit_rev8 = res;
    end
  endfunction
  function automatic [31:0] bit_rev1;
    input [31:0] rs1;
    logic [31:0] res;
    begin
      for (int i = 0; i < 32; i = i + 1) res[i] = rs1[31-i];
      bit_rev1 = res;
    end
  endfunction
  function automatic [31:0] bit_bset;
    input [31:0] rs1;
    input [31:0] rs2;
    logic [31:0] res;
    begin
      res           = rs1;
      res[rs2[4:0]] = 1'b1;
      bit_bset      = res;
    end
  endfunction
  function automatic [31:0] bit_bclr;
    input [31:0] rs1;
    input [31:0] rs2;
    logic [31:0] res;
    begin
      res           = rs1;
      res[rs2[4:0]] = 1'b0;
      bit_bclr      = res;
    end
  endfunction
  function automatic [31:0] bit_binv;
    input [31:0] rs1;
    input [31:0] rs2;
    logic [31:0] res;
    begin
      res           = rs1;
      res[rs2[4:0]] = ~res[rs2[4:0]];
      bit_binv      = res;
    end
  endfunction
  function automatic [31:0] bit_bext;
    input [31:0] rs1;
    input [31:0] rs2;
    begin
      if (rs1[rs2[4:0]] == 1) bit_bext = 1;
      else bit_bext = 0;
    end
  endfunction
  function automatic [31:0] bit_shadd;
    input [31:0] rs1;
    input [31:0] rs2;
    input [1:0] index;
    begin
      bit_shadd = rs2 + (rs1 << index);
    end
  endfunction
  function automatic rs_entry_type rs_wakeup_all;
    input rs_entry_type e;
    input cdb_type [RS_CDB_COUNT-1:0] cd;
    rs_entry_type t;
    logic [RS_CDB_COUNT-1:0] m1, m2;
    logic [31:0] d1, d2;
    logic [0:0] hit1, hit2;
    begin
      t = e;
      for (int k = 0; k < RS_CDB_COUNT; k++) begin
        m1[k] = cd[k].valid & (e.psrc1 == cd[k].tag);
        m2[k] = cd[k].valid & (e.psrc2 == cd[k].tag);
      end
      d1 = '0;
      d2 = '0;
      for (int k = 0; k < RS_CDB_COUNT; k++) begin
        d1 = d1 | ({32{m1[k]}} & cd[k].data);
        d2 = d2 | ({32{m2[k]}} & cd[k].data);
      end
      hit1 = (|m1) & ~e.src1_ready;
      hit2 = (|m2) & ~e.src2_ready;
      if (hit1) begin
        t.src1_ready = 1'b1;
        t.rdata1     = d1;
      end
      if (hit2) begin
        t.src2_ready = 1'b1;
        t.rdata2     = d2;
      end
      rs_wakeup_all = t;
    end
  endfunction
  function automatic logic [31:0] eu_result;
    input rs_entry_type e;
    input logic [31:0] npc_v;
    input logic [31:0] alu_r, agu_r, div_r, bit_r, csr_r;
    begin
      if (e.op.alunit) eu_result = alu_r;
      else if (e.op.lui) eu_result = e.imm;
      else if (e.op.auipc) eu_result = agu_r;
      else if (e.op.jal) eu_result = npc_v;
      else if (e.op.jalr) eu_result = npc_v;
      else if (e.op.division) eu_result = div_r;
      else if (e.op.bitm) eu_result = bit_r;
      else if (e.op.csreg) eu_result = csr_r;
      else eu_result = alu_r;
    end
  endfunction
  function automatic logic eu_done;
    input rs_entry_type e;
    input logic valid;
    input div_out_type dv;
    begin
      if (!valid) eu_done = 0;
      else if (e.op.mult) eu_done = 0;
      else if (e.op.division) eu_done = dv.ready;
      else eu_done = 1;
    end
  endfunction
endpackage
