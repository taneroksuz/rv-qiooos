import wires::*;
import constants::*;

module arbiter (
  input  logic        reset,
  input  logic        clock,
  input  mem_in_type  imem_in [0:1],
  output mem_out_type imem_out[0:1],
  input  mem_in_type  dmem_in [0:1],
  output mem_out_type dmem_out[0:1],
  output mem_in_type  mem_in,
  input  mem_out_type mem_out
);
  timeunit 1ns; timeprecision 1ps;

  localparam [2:0] no_access     = 0;
  localparam [2:0] instr0_access = 1;
  localparam [2:0] instr1_access = 2;
  localparam [2:0] data0_access  = 3;
  localparam [2:0] data1_access  = 4;

  typedef struct packed {
    logic [2:0]       access_type;
    mem_in_type       mem_in;
    mem_in_type [1:0] imem_in;
    mem_in_type [1:0] dmem_in;
    logic [1:0]       iactive;
    logic [1:0]       dactive;
  } reg_type;

  localparam reg_type init_reg = '{default: 0};

  reg_type r, rin;
  reg_type v;

  always_comb begin

    v = r;

    v.mem_in = init_mem_in;

    if (mem_out.mem_ready == 1) begin
      v.access_type = no_access;
    end

    v.iactive[0] = (v.access_type == instr0_access);
    v.iactive[1] = (v.access_type == instr1_access);
    v.dactive[0] = (v.access_type == data0_access);
    v.dactive[1] = (v.access_type == data1_access);

    for (int p = 0; p < 2; p++) begin
      if (dmem_in[p].mem_valid == 1 && v.dmem_in[p].mem_valid == 0 && v.dactive[p] == 0) begin
        v.dmem_in[p] = dmem_in[p];
      end
      if (imem_in[p].mem_valid == 1 && v.imem_in[p].mem_valid == 0 && v.iactive[p] == 0) begin
        v.imem_in[p] = imem_in[p];
      end
    end

    if (v.access_type == no_access) begin
      if (v.dmem_in[0].mem_valid == 1) begin
        v.access_type = data0_access;
        v.mem_in      = v.dmem_in[0];
        v.dmem_in[0]  = init_mem_in;
      end
      else if (v.dmem_in[1].mem_valid == 1) begin
        v.access_type = data1_access;
        v.mem_in      = v.dmem_in[1];
        v.dmem_in[1]  = init_mem_in;
      end
      else if (v.imem_in[0].mem_valid == 1) begin
        v.access_type = instr0_access;
        v.mem_in      = v.imem_in[0];
        v.imem_in[0]  = init_mem_in;
      end
      else if (v.imem_in[1].mem_valid == 1) begin
        v.access_type = instr1_access;
        v.mem_in      = v.imem_in[1];
        v.imem_in[1]  = init_mem_in;
      end
    end

    mem_in = v.mem_in;

    rin = v;

    dmem_out[0] = (r.access_type == data0_access) ? mem_out : init_mem_out;
    dmem_out[1] = (r.access_type == data1_access) ? mem_out : init_mem_out;
    imem_out[0] = (r.access_type == instr0_access) ? mem_out : init_mem_out;
    imem_out[1] = (r.access_type == instr1_access) ? mem_out : init_mem_out;

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_reg;
    end
    else begin
      r <= rin;
    end
  end

endmodule
