`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/20/2024 06:44:50 PM
// Design Name: 
// Module Name: IIR_2ndOrder_stateMachine
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module IIR_2ndOrder_stateMachine #(

  parameter inout_width               = 16, //1 sign bit, 4 interger bit, 11 decimal width
  parameter inout_decimal_width       = 11,
  parameter gain_width                = 16, // 1 sign bit, 8 interger bit, 7 decimal bit
  parameter gain_decimal_width        = 7,//maximum gain: +/- 256
  parameter coefficient_width         = 36,
  parameter coefficient_decimal_width = 33,
  
  //internal width has to be the sum of <maximum interger width>
  //+ <maximum decimal width> + 2 extra overflow bit
  parameter internal_width            = 44, 
  //internal decimal width has to be the <maximum decimal width>
  parameter internal_decimal_width    = 33,
  
  parameter saturation_bit            = 32767 //assume output is 16 signed bit

  )(
  input aclk,
  input resetn,

  /* slave axis interface */
  input signed [inout_width-1:0] s_axis_tdata,
  input               s_axis_tlast,
  output reg          s_axis_tready,
  input               s_axis_tvalid,
  

  /* master axis interface */
  output reg signed [inout_width-1:0] m_axis_tdata,
  output reg                          m_axis_tlast,
  input                               m_axis_tready,
  output reg                          m_axis_tvalid,
  
  //control parameters
  input signed [coefficient_width-1:0] b0, 
  input signed [coefficient_width-1:0] b1,
  input signed [coefficient_width-1:0] b2,
  input signed [coefficient_width-1:0] a1,
  input signed [coefficient_width-1:0] a2,
  
  input signed [gain_width-1:0]        gain,
  input                                OnOff, 
 
  
  output reg signed [inout_width-1:0]      data_monitor
  );
  
  wire signed [inout_width-1:0] gain_0p25;
  assign gain_0p25 = 16'd32; //for 7 decimal bits, 2^7 * 0.25;
  
 

  localparam inout_integer_width       = inout_width - inout_decimal_width; /* compute integer width */
  localparam coefficient_integer_width = coefficient_width -coefficient_decimal_width; /* compute integer width */
  localparam gain_integer_width        = gain_width -gain_decimal_width;
  localparam internal_integer_width    = internal_width - internal_decimal_width; /* compute integer width */
  
  
  
  wire signed [inout_width-1:0] saturation;
  assign saturation = saturation_bit;
  
  //e and u have to be in the same scaling
  wire signed [internal_width-1:0] input_int; /* input data internal size */
  wire signed [internal_width-1:0] b0_int; /* coefficient internal size */
  wire signed [internal_width-1:0] b1_int; /* coefficient internal size */
  wire signed [internal_width-1:0] b2_int; /* coefficient internal size */
  wire signed [internal_width-1:0] a1_int; /* coefficient internal size */
  wire signed [internal_width-1:0] a2_int; /* coefficient internal size */
  wire signed [internal_width-1:0] gain_int; /* gain internal size */
  reg  signed [internal_width-1:0] output_int; /* output internal size, before gain */
  wire signed [internal_width-1:0] saturation_int;
  
 
  reg  signed [internal_width-1:0] ekn1;
  reg  signed [internal_width-1:0] ekn2;
  reg  signed [internal_width-1:0] ukn2;
  

  reg     signed  [2*internal_width-1:0] sumA;
  reg     signed  [2*internal_width-1:0] sumB;
  reg     signed  [2*internal_width-1:0] sumC;
  reg     signed  [2*internal_width-1:0] gainOutput; //output of gain

  
  reg     signed  [internal_width-1:0]   input_sum4_int; 
  reg     signed  [2*internal_width-1:0] input_prod; 
  wire    signed  [internal_width-1:0]   gain_0p25_int; 
   
  
    /* resize signals to internal width */
    /*to align the position of the decimal point */
  assign input_int      = { {(internal_integer_width-inout_integer_width){s_axis_tdata[inout_width-1]}},
                            s_axis_tdata,
                            {(internal_decimal_width-inout_decimal_width){1'b0}} };
  assign b0_int         = { {(internal_integer_width-coefficient_integer_width){b0[coefficient_width-1]}},
                            b0,
                            {(internal_decimal_width-coefficient_decimal_width){1'b0}} };
  assign b1_int         = { {(internal_integer_width-coefficient_integer_width){b1[coefficient_width-1]}},
                            b1,
                            {(internal_decimal_width-coefficient_decimal_width){1'b0}} };
  assign b2_int         = { {(internal_integer_width-coefficient_integer_width){b2[coefficient_width-1]}},
                            b2,
                            {(internal_decimal_width-coefficient_decimal_width){1'b0}} };
  assign a1_int         = { {(internal_integer_width-coefficient_integer_width){a1[coefficient_width-1]}},
                            a1,
                            {(internal_decimal_width-coefficient_decimal_width){1'b0}} };
  assign a2_int         = { {(internal_integer_width-coefficient_integer_width){a2[coefficient_width-1]}},
                            a2,
                            {(internal_decimal_width-coefficient_decimal_width){1'b0}} };
  assign gain_int       = { {(internal_integer_width-gain_integer_width){gain[gain_width-1]}},
                            gain,
                            {(internal_decimal_width-gain_decimal_width){1'b0}} }; 
  assign saturation_int = { {(internal_integer_width-inout_integer_width){saturation[inout_width-1]}},
                            saturation,
                            {(internal_decimal_width-inout_decimal_width){1'b0}} };
  assign gain_0p25_int  = { {(internal_integer_width-gain_integer_width){gain_0p25[gain_width-1]}},
                            gain_0p25,
                            {(internal_decimal_width-gain_decimal_width){1'b0}} };
                                 

  /* tvalid, tready management */
  always @(posedge aclk)
    begin
      if (!resetn)
        begin
          m_axis_tvalid <= 1'b0;
          s_axis_tready <= 1'b0;
        end
      else
        begin
         m_axis_tvalid <= s_axis_tvalid;
         s_axis_tready <= m_axis_tready;
        end
    end
  
  /* tlast management */
  always @(posedge aclk)
    begin
      if (!resetn)
        m_axis_tlast <= 1'b0;
      else
        m_axis_tlast <= s_axis_tlast;
    end
   
   
   
      
reg [4:0] state;
// 0: registered values
// 1: take full sum
// 2: convert output to internal format
// 3: convert to m_axis

//state machine
always @(posedge aclk)
begin
  if (!resetn || !OnOff)
    begin
    input_sum4_int <= 0;
    input_prod     <= 0;
    ekn1  <= 0;
    ekn2  <= 0;
    ukn2  <= 0;
    sumA  <= 0;
    sumB  <= 0;
    sumC  <= 0;
    output_int     <= 0;
    gainOutput     <= 0;
    m_axis_tdata   <= s_axis_tdata;
    data_monitor   <= m_axis_tdata;
    state          <= 5'd0;
    end
  else 
    begin
      case (state)
        0 : //register values
          begin
            input_sum4_int <= input_int;        
            ekn1  <= (input_prod >>> internal_decimal_width); 
            ekn2  <= ekn1;
            ukn2  <= output_int;         
            sumA <= b0_int*(input_prod >>> internal_decimal_width)   - a1_int*output_int;  
            sumB <= b1_int*ekn1        - a2_int*ukn2;
            sumC <= b2_int*ekn2;
            state <= 5'd1;      
          end
        1 : //apply summation
          begin
            input_sum4_int <= input_sum4_int + input_int; 
            output_int <= (sumA+sumB+sumC) >>> internal_decimal_width;
            state <= 5'd2;
          end
        2 : //include gain
          begin
            input_sum4_int <= input_sum4_int + input_int;      
            gainOutput <= gain_int*output_int;      
            state <= 5'd3;
          end 
        3 : //convert to m_axis, take saturation into account
          begin
             input_prod <= (input_sum4_int + input_int)*gain_0p25_int;
             if ( (gainOutput >>> internal_decimal_width) >= saturation_int)
               m_axis_tdata <= saturation;
             else if ( (gainOutput >>> internal_decimal_width) <= (-saturation_int))
               m_axis_tdata <= (-saturation);
             else
               m_axis_tdata <= (gainOutput >>> 2*internal_decimal_width-inout_decimal_width);
               
             state <= 5'd0;
             data_monitor   <= m_axis_tdata;
           end
             
      endcase
    end
    
end
 
endmodule