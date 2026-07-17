module plic_granu_arb_gate(
  int_in_prio,
  int_in_req,
  int_in_id,
  int_out_req,
  int_out_id,
  int_out_prio
);
parameter    SEL_NUM        = 9;
parameter    SEL_BIT        = 4;
parameter    ID_NUM         = 10;
parameter    PRIO_BIT       = 5;

input   [SEL_NUM*PRIO_BIT-1:0]  int_in_prio;
input   [SEL_NUM-1:0]           int_in_req;
input   [SEL_NUM*ID_NUM-1:0]    int_in_id;

output                          int_out_req;
output  [ID_NUM-1:0]            int_out_id;
output  [PRIO_BIT-1:0]          int_out_prio;

function [ID_NUM+PRIO_BIT:0] pick2;
  input                     req_a;
  input [PRIO_BIT-1:0]      prio_a;
  input [ID_NUM-1:0]        id_a;
  input                     req_b;
  input [PRIO_BIT-1:0]      prio_b;
  input [ID_NUM-1:0]        id_b;
begin
  if ((req_a && !req_b) || (req_a && req_b && (prio_a > prio_b)))
    pick2 = {1'b1, prio_a, id_a};
  else if (req_b)
    pick2 = {1'b1, prio_b, id_b};
  else
    pick2 = {(ID_NUM+PRIO_BIT+1){1'b0}};
end
endfunction

wire [ID_NUM+PRIO_BIT:0] w01;
wire [ID_NUM+PRIO_BIT:0] w23;
wire [ID_NUM+PRIO_BIT:0] w45;
wire [ID_NUM+PRIO_BIT:0] w67;
wire [ID_NUM+PRIO_BIT:0] w0123;
wire [ID_NUM+PRIO_BIT:0] w4567;
wire [ID_NUM+PRIO_BIT:0] w01234567;
wire [ID_NUM+PRIO_BIT:0] w8;
wire [ID_NUM+PRIO_BIT:0] winner;

assign w01 = pick2(int_in_req[0], int_in_prio[0*PRIO_BIT+:PRIO_BIT], int_in_id[0*ID_NUM+:ID_NUM],
                   int_in_req[1], int_in_prio[1*PRIO_BIT+:PRIO_BIT], int_in_id[1*ID_NUM+:ID_NUM]);
assign w23 = pick2(int_in_req[2], int_in_prio[2*PRIO_BIT+:PRIO_BIT], int_in_id[2*ID_NUM+:ID_NUM],
                   int_in_req[3], int_in_prio[3*PRIO_BIT+:PRIO_BIT], int_in_id[3*ID_NUM+:ID_NUM]);
assign w45 = pick2(int_in_req[4], int_in_prio[4*PRIO_BIT+:PRIO_BIT], int_in_id[4*ID_NUM+:ID_NUM],
                   int_in_req[5], int_in_prio[5*PRIO_BIT+:PRIO_BIT], int_in_id[5*ID_NUM+:ID_NUM]);
assign w67 = pick2(int_in_req[6], int_in_prio[6*PRIO_BIT+:PRIO_BIT], int_in_id[6*ID_NUM+:ID_NUM],
                   int_in_req[7], int_in_prio[7*PRIO_BIT+:PRIO_BIT], int_in_id[7*ID_NUM+:ID_NUM]);
assign w8  = {int_in_req[8], int_in_prio[8*PRIO_BIT+:PRIO_BIT], int_in_id[8*ID_NUM+:ID_NUM]};

assign w0123 = pick2(w01[ID_NUM+PRIO_BIT], w01[ID_NUM+PRIO_BIT-1:ID_NUM], w01[ID_NUM-1:0],
                     w23[ID_NUM+PRIO_BIT], w23[ID_NUM+PRIO_BIT-1:ID_NUM], w23[ID_NUM-1:0]);
assign w4567 = pick2(w45[ID_NUM+PRIO_BIT], w45[ID_NUM+PRIO_BIT-1:ID_NUM], w45[ID_NUM-1:0],
                     w67[ID_NUM+PRIO_BIT], w67[ID_NUM+PRIO_BIT-1:ID_NUM], w67[ID_NUM-1:0]);
assign w01234567 = pick2(w0123[ID_NUM+PRIO_BIT], w0123[ID_NUM+PRIO_BIT-1:ID_NUM], w0123[ID_NUM-1:0],
                         w4567[ID_NUM+PRIO_BIT], w4567[ID_NUM+PRIO_BIT-1:ID_NUM], w4567[ID_NUM-1:0]);
assign winner = pick2(w01234567[ID_NUM+PRIO_BIT], w01234567[ID_NUM+PRIO_BIT-1:ID_NUM], w01234567[ID_NUM-1:0],
                      w8[ID_NUM+PRIO_BIT], w8[ID_NUM+PRIO_BIT-1:ID_NUM], w8[ID_NUM-1:0]);

assign int_out_req  = winner[ID_NUM+PRIO_BIT];
assign int_out_prio = winner[ID_NUM+PRIO_BIT-1:ID_NUM];
assign int_out_id   = winner[ID_NUM-1:0];

endmodule
