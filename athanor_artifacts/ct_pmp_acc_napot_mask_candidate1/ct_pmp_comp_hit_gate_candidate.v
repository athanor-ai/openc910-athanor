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
module ct_pmp_comp_hit(
  addr_match_mode_x,
  mmu_addr_ge_bottom_x,
  mmu_addr_ge_upaddr_x,
  mmu_pmp_pa_y,
  pmp_mmu_hit_x,
  pmpaddr_x_value
);

// &Ports; @25
input   [1 :0]  addr_match_mode_x;   
input           mmu_addr_ge_bottom_x; 
input   [27:0]  mmu_pmp_pa_y;        
input   [28:0]  pmpaddr_x_value;     
output          mmu_addr_ge_upaddr_x; 
output          pmp_mmu_hit_x;       

// &Regs; @26
reg             pmp_mmu_hit_x;       

// &Wires; @27
wire    [1 :0]  addr_match_mode_x;   
wire    [27:0]  addr_mask;           
wire            mmu_addr_ge_bottom_x; 
wire            mmu_addr_ge_upaddr_x; 
wire            mmu_addr_ls_top;     
wire    [28:0]  mmu_comp_adder;      
wire            mmu_na4_addr_match;  
wire            mmu_napot_addr_match; 
wire    [27:0]  mmu_pmp_pa_y;        
wire            mmu_tor_addr_match;  
wire    [28:0]  pmpaddr_x_value;     


parameter ADDR_WIDTH = `PA_WIDTH-12;

// //&Force("bus","pmpaddr_x_value",27,0); @31
//==========================================================
//                Address Matching Logic
//==========================================================
//Compare access address by four address-matching mode,and 
//generate address hit information for read uint(mmu)
// &CombBeg; @37
always @( addr_match_mode_x[1:0]
       or mmu_tor_addr_match
       or mmu_na4_addr_match
       or mmu_napot_addr_match)
begin
  case(addr_match_mode_x[1:0])
    2'b00:   pmp_mmu_hit_x = 1'b0;                 //OFF
    2'b01:   pmp_mmu_hit_x = mmu_tor_addr_match;   //TOR 
    2'b10:   pmp_mmu_hit_x = mmu_na4_addr_match;   //NA4
    2'b11:   pmp_mmu_hit_x = mmu_napot_addr_match; //NAPOT
    default: pmp_mmu_hit_x = 1'b0; 
  endcase
// &CombEnd; @45
end


//1. TOR mode : pmpaddr_x_value[i-1]<= addr < pmpaddr_x_value[i]
assign mmu_comp_adder[ADDR_WIDTH:0] = {1'b0,mmu_pmp_pa_y[ADDR_WIDTH-1:0]} - 
                                      {1'b0,pmpaddr_x_value[ADDR_WIDTH:1]};
assign mmu_addr_ls_top      = mmu_comp_adder[ADDR_WIDTH];
assign mmu_tor_addr_match   = mmu_addr_ge_bottom_x && mmu_addr_ls_top;

// for next entry
assign mmu_addr_ge_upaddr_x  = !mmu_comp_adder[ADDR_WIDTH];

//2. NAPOT : addr &addr_mask == pmpaddr_x_value & addr_mask
assign mmu_napot_addr_match = (addr_mask[ADDR_WIDTH-1:0] & mmu_pmp_pa_y[ADDR_WIDTH-1:0]) == (addr_mask[ADDR_WIDTH-1:0] & pmpaddr_x_value[ADDR_WIDTH:1]);
//assign mmu_napot_addr_match = (addr_mask[ADDR_WIDTH-1:0] & mmu_pmp_pa_y[ADDR_WIDTH-1:0]) == pmpaddr_x_value[ADDR_WIDTH:1];

//3. NA4 : addr[31:2] == pmpaddr_x_value[29:0]
//assign mmu_na4_addr_match   = (mmu_pmp_pa_y[31:2] == pmpaddr_x_value[29:0]);
assign mmu_na4_addr_match   = 1'b0;

assign addr_mask[0]  = ~pmpaddr_x_value[0];
assign addr_mask[1]  = ~&pmpaddr_x_value[1:0];
assign addr_mask[2]  = ~&pmpaddr_x_value[2:0];
assign addr_mask[3]  = ~&pmpaddr_x_value[3:0];
assign addr_mask[4]  = ~&pmpaddr_x_value[4:0];
assign addr_mask[5]  = ~&pmpaddr_x_value[5:0];
assign addr_mask[6]  = ~&pmpaddr_x_value[6:0];
assign addr_mask[7]  = ~&pmpaddr_x_value[7:0];
assign addr_mask[8]  = ~&pmpaddr_x_value[8:0];
assign addr_mask[9]  = ~&pmpaddr_x_value[9:0];
assign addr_mask[10] = ~&pmpaddr_x_value[10:0];
assign addr_mask[11] = ~&pmpaddr_x_value[11:0];
assign addr_mask[12] = ~&pmpaddr_x_value[12:0];
assign addr_mask[13] = ~&pmpaddr_x_value[13:0];
assign addr_mask[14] = ~&pmpaddr_x_value[14:0];
assign addr_mask[15] = ~&pmpaddr_x_value[15:0];
assign addr_mask[16] = ~&pmpaddr_x_value[16:0];
assign addr_mask[17] = ~&pmpaddr_x_value[17:0];
assign addr_mask[18] = ~&pmpaddr_x_value[18:0];
assign addr_mask[19] = ~&pmpaddr_x_value[19:0];
assign addr_mask[20] = ~&pmpaddr_x_value[20:0];
assign addr_mask[21] = ~&pmpaddr_x_value[21:0];
assign addr_mask[22] = ~&pmpaddr_x_value[22:0];
assign addr_mask[23] = ~&pmpaddr_x_value[23:0];
assign addr_mask[24] = ~&pmpaddr_x_value[24:0];
assign addr_mask[25] = ~&pmpaddr_x_value[25:0];
assign addr_mask[26] = ~&pmpaddr_x_value[26:0];
assign addr_mask[27] = ~&pmpaddr_x_value[27:0];

// &ModuleEnd; @104
endmodule

