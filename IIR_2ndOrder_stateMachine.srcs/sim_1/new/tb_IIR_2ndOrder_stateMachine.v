`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/20/2024 06:45:15 PM
// Design Name: 
// Module Name: tb_IIR_secondOrder_stateMachine
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


module tb_IIR_secondOrder_stateMachine();

    reg aclk, resetn, s_axis_tvalid, s_axis_tlast;
    reg signed [15:0] s_axis_tdata;
    wire m_axis_tvalid;
    wire signed [15:0] m_axis_tdata;
    reg m_axis_tready;
    wire signed [15:0] data_monitor;
     
    

    always begin
       aclk = 1; #5;
       aclk = 0; #5;
    end
   
    
    initial begin
        resetn = 1;  #40;
        resetn = 0;  #40;
        resetn = 1;  #40;
    end
    
    initial begin
        s_axis_tvalid = 0; s_axis_tlast =0; m_axis_tready =0; #80;
        s_axis_tvalid = 1; s_axis_tlast =1; m_axis_tready =1; #80;
    end
    
 
    
    /* Instantiate bandPass module to test. */
    IIR_2ndOrder_stateMachine #(
    .saturation_bit(32767) 
    ) inst_IIR_2ndOrder_stateMachine
    (
      .aclk(aclk),
      .resetn(resetn),
      .s_axis_tdata(s_axis_tdata),    
      .s_axis_tlast(s_axis_tlast),   
      .s_axis_tvalid(s_axis_tvalid), 
      .s_axis_tready(s_axis_tready), 
      .m_axis_tdata(m_axis_tdata),
      .m_axis_tlast(m_axis_tlast),  
      .m_axis_tvalid(m_axis_tvalid), 
      .m_axis_tready(m_axis_tready),
   /*    // 100/2 MHz, 500Hz notch filter, (28,25)-bit wont work
      .b0 ( 28'd33554221),//numerators
      .b1 (-28'd67108443),
      .b2 ( 28'd33554221),
      .a1 (-28'd67108443),//denominators
      .a2 ( 28'd33554010), */
   /*   // 100/2 MHz, 500Hz notch filter, (32,29)-bit wont work
      .b0 ( 32'd536867538),//numerators
      .b1 (-32'd1073735076),
      .b2 ( 32'd536867538),
      .a1 (-32'd1073735076),//denominators
      .a2 ( 32'd536864165),  */
  /*     // 100/2 MHz, 500Hz notch filter, (32,29)-bit wont work
      .b0 ( 36'd8589880620),//numerators
      .b1 (-36'd17179761207),
      .b2 ( 36'd8589880620),
      .a1 (-36'd17179761207),//denominators
      .a2 ( 36'd8589826648),  */
      // 100/4 MHz, 500Hz notch filter
   /*   .b0 ( 32'd536864165),//numerators
      .b1 (-32'd1073728323),
      .b2 ( 32'd536864165),
      .a1 (-32'd1073728323),//denominators
      .a2 ( 32'd536857419),  */
      // 100/4 MHz, 500Hz notch filter
      .b0 ( 36'd8589826649),//numerators
      .b1 (-36'd17179653163),
      .b2 ( 36'd8589826649),
      .a1 (-36'd17179653163),//denominators
      .a2 ( 36'd8589718706),        
      .gain(128), //value = gain*2^7
      .OnOff(1),
      .data_monitor(data_monitor)      
    );
    
    

    reg [4:0] state_reg;
    reg [15:0] cntr;
    
    parameter wvfm_period = 16'd2500; //25000 for 500Hz
    
    parameter init               = 5'd0;
    parameter sendSample0        = 5'd1;
    parameter sendSample1        = 5'd2;
    parameter sendSample2        = 5'd3;
    parameter sendSample3        = 5'd4;
    parameter sendSample4        = 5'd5;
    parameter sendSample5        = 5'd6;
    parameter sendSample6        = 5'd7;
    parameter sendSample7        = 5'd8;
    
    /* This state machine generates a 1/(8*10ns*wvfm_period) sinusoid. */
    always @ (posedge aclk or negedge resetn)
        begin
            if (resetn == 1'b0)
                begin
                    cntr <= 16'd0;
                    s_axis_tdata <= 16'd0;
                    state_reg <= init;
                end
            else
                begin
                    case (state_reg)
                        init : //0
                            begin
                                cntr <= 16'd0;
                                s_axis_tdata <= 16'h0000;
                                state_reg <= sendSample0;
                            end
                            
                        sendSample0 : //1
                            begin
                                s_axis_tdata <= 16'h0000;
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample1;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample0;
                                    end
                            end 
                        
                        sendSample1 : //2
                            begin
                                s_axis_tdata <= 16'h5A81;
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample2;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample1;
                                    end
                            end 
                        
                        sendSample2 : //3
                            begin
                                s_axis_tdata <= 16'h7FFF;//16'h1fff;//
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample3;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample2;
                                    end
                            end 
                        
                        sendSample3 : //4
                            begin
                                s_axis_tdata <= 16'h5A81;//16'h16a0;
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample4;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample3;
                                    end
                            end 
                        
                        sendSample4 : //5
                            begin
                                s_axis_tdata <= 16'hffff;
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample5;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample4;
                                    end
                            end 
                        
                        sendSample5 : //6
                            begin
                                s_axis_tdata <=16'hA57e;// 16'he960;// 
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample6;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample5;
                                    end
                            end 
                        
                        sendSample6 : //6
                            begin
                                s_axis_tdata <=16'h8001; // 16'he001;//
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample7;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample6;
                                    end
                            end 
                        
                        sendSample7 : //6
                            begin
                                s_axis_tdata <= 16'hA57e;//16'he960;// 
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample0;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample7;
                                    end
                            end                     
                    
                    endcase
                end
        end
        
endmodule