import wires::*;

module mul (
  input  logic        reset,
  input  logic        clock,
  input  mul_in_type  mul_in,
  output mul_out_type mul_out
);
  timeunit 1ns; timeprecision 1ps;

  logic signed [32:0] op1;
  logic signed [32:0] op2;

  logic signed [32:0] op1_q;
  logic signed [32:0] op2_q;

  logic signed [65:0] result;

  mul_op_type mul_op;
  mul_op_type mul_op_q;

  logic [0:0] op1_signed;
  logic [0:0] op2_signed;

  always_comb begin

    op1        = {1'b0, mul_in.rdata1};
    op2        = {1'b0, mul_in.rdata2};
    mul_op     = mul_in.mul_op;
    op1_signed = mul_op.muls | mul_op.mulh | mul_op.mulhsu;
    op2_signed = mul_op.muls | mul_op.mulh;
    if (op1_signed == 1) begin
      op1[32] = op1[31];
    end
    if (op2_signed == 1) begin
      op2[32] = op2[31];
    end

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      op1_q    <= '0;
      op2_q    <= '0;
      mul_op_q <= init_mul_op;
    end
    else begin
      op1_q    <= op1;
      op2_q    <= op2;
      mul_op_q <= mul_op;
    end
  end

  always_comb begin

    result = op1_q * op2_q;
    if (mul_op_q.muls == 1) begin
      mul_out.result = result[31:0];
    end
    else begin
      mul_out.result = result[63:32];
    end

  end

endmodule
