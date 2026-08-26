package tim_wires;
  timeunit 1ns; timeprecision 1ps;

  import configure::*;

  localparam TIM_WORDS = TIM_WIDTH * TIM_DEPTH;
  localparam TADDR     = $clog2(TIM_WORDS);

  typedef struct packed {
    logic [1:0][0:0]       en;
    logic [1:0][TADDR-1:0] addr;
    logic [1:0][3:0]       strb;
    logic [1:0][31:0]      data;
  } tim_ram_in_type;

  typedef struct packed {logic [1:0][31:0] data;} tim_ram_out_type;

  localparam tim_ram_in_type  init_tim_ram_in  = '{default: '0};
  localparam tim_ram_out_type init_tim_ram_out = '{default: '0};

endpackage

import configure::*;
import wires::*;
import tim_wires::*;

module tim_ram (
  input  logic            clock,
  input  tim_ram_in_type  tim_ram_in,
  output tim_ram_out_type tim_ram_out
);
  timeunit 1ns; timeprecision 1ps;

  logic [31:0] tim_ram[0:TIM_WORDS-1] = '{default: '0};

  always_ff @(posedge clock) begin
    for (int p = 0; p < 2; p++) begin
      if (tim_ram_in.en[p] == 1) begin
        if (tim_ram_in.strb[p][0]) tim_ram[tim_ram_in.addr[p]][7:0] <= tim_ram_in.data[p][7:0];
        if (tim_ram_in.strb[p][1]) tim_ram[tim_ram_in.addr[p]][15:8] <= tim_ram_in.data[p][15:8];
        if (tim_ram_in.strb[p][2]) tim_ram[tim_ram_in.addr[p]][23:16] <= tim_ram_in.data[p][23:16];
        if (tim_ram_in.strb[p][3]) tim_ram[tim_ram_in.addr[p]][31:24] <= tim_ram_in.data[p][31:24];
        tim_ram_out.data[p] <= tim_ram[tim_ram_in.addr[p]];
      end
    end
  end

endmodule

module tim_ctrl (
  input  logic            reset,
  input  logic            clock,
  input  tim_ram_out_type dvec_out,
  output tim_ram_in_type  dvec_in,
  input  mem_in_type      tim_in  [0:1],
  output mem_out_type     tim_out [0:1]
);
  timeunit 1ns; timeprecision 1ps;

  typedef struct packed {
    logic [1:0][TADDR-1:0] did;
    logic [1:0][31:0]      data;
    logic [1:0][3:0]       strb;
    logic [1:0][0:0]       valid;
  } front_type;

  typedef struct packed {
    logic [1:0][TADDR-1:0] did;
    logic [1:0][31:0]      rdata;
    logic [1:0][31:0]      data;
    logic [1:0][3:0]       strb;
    logic [1:0][0:0]       valid;
  } back_type;

  parameter front_type init_front = 0;
  parameter back_type  init_back  = 0;

  front_type r_f, rin_f;
  front_type v_f;

  back_type r_b, rin_b;
  back_type v_b;

  always_comb begin

    v_f = r_f;

    for (int p = 0; p < 2; p++) begin
      v_f.valid[p] = 0;
      v_f.strb[p]  = 0;

      if (tim_in[p].mem_valid == 1) begin
        v_f.valid[p] = tim_in[p].mem_valid;
        v_f.strb[p]  = tim_in[p].mem_wstrb;
        v_f.data[p]  = tim_in[p].mem_wdata;
        v_f.did[p]   = tim_in[p].mem_addr[(TADDR+1):2];
      end
    end

    dvec_in = init_tim_ram_in;

    for (int p = 0; p < 2; p++) begin
      dvec_in.en[p]   = v_f.valid[p];
      dvec_in.strb[p] = v_f.strb[p];
      dvec_in.addr[p] = v_f.did[p];
      dvec_in.data[p] = v_f.data[p];
    end

    rin_f = v_f;

  end

  always_comb begin

    v_b = r_b;

    for (int p = 0; p < 2; p++) begin
      v_b.valid[p] = r_f.valid[p];
      v_b.data[p]  = r_f.data[p];
      v_b.strb[p]  = r_f.strb[p];
      v_b.did[p]   = r_f.did[p];

      v_b.rdata[p] = dvec_out.data[p];
    end

    if (|(v_b.strb[1]) == 0 && v_b.did[0] == v_b.did[1]) begin
      v_b.rdata[1][7:0]   = v_b.strb[0][0] ? v_b.data[0][7:0] : v_b.rdata[1][7:0];
      v_b.rdata[1][15:8]  = v_b.strb[0][1] ? v_b.data[0][15:8] : v_b.rdata[1][15:8];
      v_b.rdata[1][23:16] = v_b.strb[0][2] ? v_b.data[0][23:16] : v_b.rdata[1][23:16];
      v_b.rdata[1][31:24] = v_b.strb[0][3] ? v_b.data[0][31:24] : v_b.rdata[1][31:24];
    end

    for (int p = 0; p < 2; p++) begin
      tim_out[p].mem_rdata = v_b.rdata[p];
      tim_out[p].mem_error = 0;
      tim_out[p].mem_ready = v_b.valid[p];
    end

    rin_b = v_b;

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r_f <= init_front;
      r_b <= init_back;
    end
    else begin
      r_f <= rin_f;
      r_b <= rin_b;
    end
  end

endmodule

module tim (
  input  logic        reset,
  input  logic        clock,
  input  mem_in_type  tim_in [0:1],
  output mem_out_type tim_out[0:1]
);
  timeunit 1ns; timeprecision 1ps;

  tim_ram_in_type  dvec_in;
  tim_ram_out_type dvec_out;

  tim_ram tim_ram_comp (
    .clock      (clock),
    .tim_ram_in (dvec_in),
    .tim_ram_out(dvec_out)
  );

  tim_ctrl tim_ctrl_comp (
    .reset   (reset),
    .clock   (clock),
    .dvec_out(dvec_out),
    .dvec_in (dvec_in),
    .tim_in  (tim_in),
    .tim_out (tim_out)
  );

endmodule
