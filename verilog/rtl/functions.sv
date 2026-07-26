package functions;
  timeunit 1ns; timeprecision 1ps;
  import configure::*;
  import wires::*;
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
  function automatic [31:0] bit_clz;
    input [31:0] rs1;
    logic [5:0] res;
    begin
      res = 0;
      for (int i = 31; i >= 0; i = i - 1) begin
        if (rs1[i] == 1) break;
        res = res + 1;
      end
      bit_clz = {26'h0, res};
    end
  endfunction
  function automatic [31:0] bit_ctz;
    input [31:0] rs1;
    logic [5:0] res;
    begin
      res = 0;
      for (int i = 0; i < 32; i = i + 1) begin
        if (rs1[i] == 1) break;
        res = res + 1;
      end
      bit_ctz = {26'h0, res};
    end
  endfunction
  function automatic [31:0] bit_cpop;
    input [31:0] rs1;
    logic [5:0] res;
    begin
      res = 0;
      for (int i = 0; i < 32; i = i + 1) if (rs1[i] == 1) res = res + 1;
      bit_cpop = {26'h0, res};
    end
  endfunction
  function automatic [31:0] bit_minmax;
    input [31:0] rs1;
    input [31:0] rs2;
    input [1:0] op;
    logic [32:0] r1, r2;
    begin
      r1 = {1'b0, rs1};
      r2 = {1'b0, rs2};
      if (op == 0 || op == 2) begin
        r1[32] = rs1[31];
        r2[32] = rs2[31];
      end
      if (op == 2 || op == 3) begin
        r1 = -r1;
        r2 = -r2;
      end
      if ($signed(r1) < $signed(r2)) bit_minmax = rs2;
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
  function automatic [31:0] bit_rol;
    input [31:0] rs1;
    input [31:0] rs2;
    logic [31:0] res;
    begin
      res     = rs1 << rs2[4:0];
      bit_rol = res | (rs1 >> (32 - rs2[4:0]));
    end
  endfunction
  function automatic [31:0] bit_ror;
    input [31:0] rs1;
    input [31:0] rs2;
    logic [31:0] res;
    begin
      res     = rs1 >> rs2[4:0];
      bit_ror = res | (rs1 << (32 - rs2[4:0]));
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
  function automatic rs_entry_type rs_wakeup;
    input rs_entry_type e;
    input cdb_type c;
    rs_entry_type t;
    begin
      t = e;
      if (c.valid && t.valid) begin
        if (!t.src1_ready && t.psrc1 == c.tag) begin
          t.src1_ready = 1'b1;
          t.rdata1     = c.data;
        end
        if (!t.src2_ready && t.psrc2 == c.tag) begin
          t.src2_ready = 1'b1;
          t.rdata2     = c.data;
        end
      end
      rs_wakeup = t;
    end
  endfunction
  function automatic logic [31:0] prf_or_cdb;
    input logic [PRF_ADDR_BITS-1:0] tag;
    input logic prf_valid;
    input logic [31:0] prf_data;
    input cdb_type [0:3] c;
    input cdb_type cl;
    begin
      prf_or_cdb = 32'h0;
      if (prf_valid) prf_or_cdb = prf_data;
      for (int k = 0; k < 4; k++) begin
        if (c[k].valid && c[k].tag == tag) prf_or_cdb = c[k].data;
      end
      if (cl.valid && cl.tag == tag) prf_or_cdb = cl.data;
    end
  endfunction
  function automatic logic src_ready;
    input logic [PRF_ADDR_BITS-1:0] tag;
    input logic prf_valid;
    input cdb_type [0:3] c;
    input cdb_type cl;
    begin
      src_ready = prf_valid;
      for (int k = 0; k < 4; k++) begin
        if (c[k].valid && c[k].tag == tag) src_ready = 1'b1;
      end
      if (cl.valid && cl.tag == tag) src_ready = 1'b1;
    end
  endfunction
  function automatic logic [31:0] eu_result;
    input rs_entry_type e;
    input logic [31:0] alu_r, agu_r, mul_r, div_r, bit_r, csr_r, bc_r;
    begin
      if (e.op.alunit) eu_result = alu_r;
      else if (e.op.lui) eu_result = e.imm;
      else if (e.op.auipc) eu_result = agu_r;
      else if (e.op.jal) eu_result = e.npc;
      else if (e.op.jalr) eu_result = e.npc;
      else if (e.op.mult) eu_result = mul_r;
      else if (e.op.division) eu_result = div_r;
      else if (e.op.bitm) eu_result = bit_r;
      else if (e.op.bitc) eu_result = bc_r;
      else if (e.op.csreg) eu_result = csr_r;
      else eu_result = alu_r;
    end
  endfunction
  function automatic logic eu_done;
    input rs_entry_type e;
    input logic valid;
    input div_out_type dv;
    input bit_clmul_out_type bc;
    begin
      if (!valid) eu_done = 0;
      else if (e.op.division) eu_done = dv.ready;
      else if (e.op.bitc) eu_done = bc.ready;
      else eu_done = 1;
    end
  endfunction
endpackage
