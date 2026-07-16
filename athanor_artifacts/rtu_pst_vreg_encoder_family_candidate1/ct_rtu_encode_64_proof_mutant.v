/*Copyright 2019-2021 T-Head Semiconductor Co., Ltd.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// &ModuleBeg; @24
module ct_rtu_encode_64(
  x_num,
  x_num_expand
);

// &Ports; @25
input   [63:0]  x_num_expand; 
output  [5 :0]  x_num;       

// &Regs; @26

// &Wires; @27
wire    [5 :0]  x_num;       
wire    [63:0]  x_num_expand; 


//==========================================================
//  encode 64 bits one-hot number to 6 bits binary number
//==========================================================
assign x_num[0] = |(x_num_expand[63:0] & 64'h2AAA_AAAA_AAAA_AAAA);
assign x_num[1] = |(x_num_expand[63:0] & 64'hCCCC_CCCC_CCCC_CCCC);
assign x_num[2] = |(x_num_expand[63:0] & 64'hF0F0_F0F0_F0F0_F0F0);
assign x_num[3] = |(x_num_expand[63:0] & 64'hFF00_FF00_FF00_FF00);
assign x_num[4] = |(x_num_expand[63:0] & 64'hFFFF_0000_FFFF_0000);
assign x_num[5] = |(x_num_expand[63:0] & 64'hFFFF_FFFF_0000_0000);

// &ModuleEnd; @98
endmodule


