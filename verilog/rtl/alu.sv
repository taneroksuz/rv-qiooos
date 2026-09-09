import wires::*;
import functions::*;

module alu (
  input  alu_in_type  alu_in,
  output alu_out_type alu_out
);
  timeunit 1ns; timeprecision 1ps;

  logic [31:0] rdata2;
  logic [31:0] result;

  logic [ 0:0] subtract;
  logic [31:0] addend;
  logic [32:0] sum;
  logic [ 0:0] less_signed;
  logic [ 0:0] less_unsigned;

  logic [ 4:0] shamt;
  logic [31:0] reversed;
  logic [31:0] shift_in;
  logic [32:0] shift_ext;
  logic [31:0] shift_right;
  logic [31:0] shift_back;
  logic [31:0] shift_result;

  always_comb begin

    rdata2 = multiplexer(alu_in.imm, alu_in.rdata2, alu_in.sel);
    result = 0;

    subtract = alu_in.alu_op.alu_sub | alu_in.alu_op.alu_slt | alu_in.alu_op.alu_sltu;
    addend   = subtract ? ~rdata2 : rdata2;
    sum      = {1'b0, alu_in.rdata1} + {1'b0, addend} + 33'(subtract);

    less_signed   = (alu_in.rdata1[31] ^ rdata2[31]) ? alu_in.rdata1[31] : sum[31];
    less_unsigned = ~sum[32];

    shamt = rdata2[4:0];
    for (int i = 0; i < 32; i = i + 1) begin
      reversed[i] = alu_in.rdata1[31-i];
    end
    shift_in    = alu_in.alu_op.alu_sll ? reversed : alu_in.rdata1;
    shift_ext   = {alu_in.alu_op.alu_sra & alu_in.rdata1[31], shift_in};
    shift_right = 32'($signed(shift_ext) >>> shamt);
    for (int i = 0; i < 32; i = i + 1) begin
      shift_back[i] = shift_right[31-i];
    end
    shift_result = alu_in.alu_op.alu_sll ? shift_back : shift_right;

    if ((alu_in.alu_op.alu_add | alu_in.alu_op.alu_sub) == 1) begin
      result = sum[31:0];
    end
    else if ((alu_in.alu_op.alu_sll | alu_in.alu_op.alu_srl | alu_in.alu_op.alu_sra) == 1) begin
      result = shift_result;
    end
    else if (alu_in.alu_op.alu_slt == 1) begin
      result[0] = less_signed;
    end
    else if (alu_in.alu_op.alu_sltu == 1) begin
      result[0] = less_unsigned;
    end
    else if (alu_in.alu_op.alu_and == 1) begin
      result = alu_in.rdata1 & rdata2;
    end
    else if (alu_in.alu_op.alu_or == 1) begin
      result = alu_in.rdata1 | rdata2;
    end
    else if (alu_in.alu_op.alu_xor == 1) begin
      result = alu_in.rdata1 ^ rdata2;
    end

    alu_out.result = result;

  end

endmodule
