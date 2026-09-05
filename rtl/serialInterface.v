
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// serialInterface.v                                                 ////
////                                                              ////
//// This file is part of the i2cSlave opencores effort.
//// <http://www.opencores.org/cores//>                           ////
////                                                              ////
//// Module Description:                                          ////
//// Perform all serial to parallel, and parallel
//// to serial conversions. Perform device address matching
//// Handle arbitrary length I2C reads terminated by NAK
//// from host, and arbitrary length I2C writes terminated
//// by STOP from host
//// The second byte of a I2C write is always interpreted
//// as a register address, and becomes the base register address
//// for all read and write transactions.
//// I2C WRITE:    devAddr, regAddr, data[regAddr], data[regAddr+1], ..... data[regAddr+N]
//// I2C READ:    data[regAddr], data[regAddr+1], ..... data[regAddr+N]
//// Note that when regAddR reaches 255 it will automatically wrap round to 0
////                                                              ////
//// To Do:                                                       ////
//// 
////                                                              ////
//// Author(s):                                                   ////
//// - Steve Fielding, sfielding@base2designs.com                 ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2008 Steve Fielding and OPENCORES.ORG          ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE. See the GNU Lesser General Public License for more  ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from <http://www.opencores.org/lgpl.shtml>                   ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
`include "i2cSlave_define.v"

module serialInterface (
  input   clk,
  input   [7:0] dataIn,
  input   rst,
  input   scl,
  input   sdaIn,
  input   [1:0] startStopDetState,
  output  reg clearStartStopDet,
  output  reg [7:0] dataOut,
  output  reg [7:0] regAddr,
  output  reg sdaOut,
  output  reg writeEn
);

// Diagram signals declarations
reg  [2:0] bitCnt;
reg  [7:0] rxData;
reg  [1:0] streamSt;
reg  [7:0] txData;

// Combinational signals
reg  [2:0] next_bitCnt;
reg  [7:0] next_rxData;
reg  [1:0] next_streamSt;
reg  [7:0] next_txData;
reg  next_clearStartStopDet;
reg  [7:0] next_dataOut;
reg  [7:0] next_regAddr;
reg  next_sdaOut;
reg  next_writeEn;

// BINARY ENCODED state machine: SISt
// State codes definitions using localparam
localparam START = 4'b0000;
localparam CHK_RD_WR = 4'b0001;
localparam READ_RD_LOOP = 4'b0010;
localparam READ_WT_HI = 4'b0011;
localparam READ_CHK_LOOP_FIN = 4'b0100;
localparam READ_WT_LO = 4'b0101;
localparam READ_WT_ACK = 4'b0110;
localparam WRITE_WT_LO = 4'b0111;
localparam WRITE_WT_HI = 4'b1000;
localparam WRITE_CHK_LOOP_FIN = 4'b1001;
localparam WRITE_LOOP_WT_LO = 4'b1010;
localparam WRITE_ST_LOOP = 4'b1011;
localparam WRITE_WT_LO2 = 4'b1100;
localparam WRITE_WT_HI2 = 4'b1101;
localparam WRITE_CLR_WR = 4'b1110;

reg [3:0] CurrState_SISt;
reg [3:0] NextState_SISt;

// NextState logic (combinational)
always @(*) begin
  // Default assignments to prevent latches
  next_txData = txData;
  next_rxData = rxData;
  next_sdaOut = sdaOut;
  next_writeEn = writeEn;
  next_dataOut = dataOut;
  next_bitCnt = bitCnt;
  next_clearStartStopDet = clearStartStopDet;
  next_regAddr = regAddr;

  case (CurrState_SISt)
    START: begin
      next_streamSt = `STREAM_IDLE;
      next_txData = 8'h00;
      next_rxData = 8'h00;
      next_sdaOut = 1'b1;
      next_writeEn = 1'b0;
      next_dataOut = 8'h00;
      next_bitCnt = 3'b000;
      next_clearStartStopDet = 1'b0;
      next_regAddr = regAddr;
      NextState_SISt = CHK_RD_WR;
    end
    CHK_RD_WR: begin
      if (streamSt == `STREAM_READ) begin
        NextState_SISt = READ_RD_LOOP;
        next_txData = dataIn;
        next_regAddr = regAddr + 8'b1;
        next_bitCnt = 3'b001;
      end else begin
        NextState_SISt = WRITE_WT_HI;
        next_rxData = 8'h00;
      end
      next_streamSt = streamSt;
      next_sdaOut = sdaOut;
      next_writeEn = writeEn;
      next_dataOut = dataOut;
      next_clearStartStopDet = clearStartStopDet;
    end
    READ_RD_LOOP: begin
      if (scl == 1'b0) begin
        NextState_SISt = READ_WT_HI;
        next_sdaOut = txData[7];
        next_txData = {txData[6:0], 1'b0};
      end else begin
        NextState_SISt = READ_RD_LOOP;
      end
      next_streamSt = streamSt;
      next_rxData = rxData;
      next_writeEn = writeEn;
      next_dataOut = dataOut;
      next_bitCnt = bitCnt;
      next_clearStartStopDet = clearStartStopDet;
      next_regAddr = regAddr;
    end
    READ_WT_HI: begin
      if (scl == 1'b1) begin
        NextState_SISt = READ_CHK_LOOP_FIN;
      end else begin
        NextState_SISt = READ_WT_HI;
      end
      next_streamSt = streamSt;
      next_txData = txData;
      next_rxData = rxData;
      next_sdaOut = sdaOut;
      next_writeEn = writeEn;
      next_dataOut = dataOut;
      next_bitCnt = bitCnt;
      next_clearStartStopDet = clearStartStopDet;
      next_regAddr = regAddr;
    end
    READ_CHK_LOOP_FIN: begin
      if (bitCnt == 3'b000) begin
        NextState_SISt = READ_WT_LO;
      end else begin
        NextState_SISt = READ_RD_LOOP;
        next_bitCnt = bitCnt + 3'b1;
      end
      next_streamSt = streamSt;
      next_txData = txData;
      next_rxData = rxData;
      next_sdaOut = sdaOut;
      next_writeEn = writeEn;
      next_dataOut = dataOut;
      next_clearStartStopDet = clearStartStopDet;
      next_regAddr = regAddr;
    end
    READ_WT_LO: begin
      if (scl == 1'b0) begin
        NextState_SISt = READ_WT_ACK;
        next_sdaOut = 1'b1;
      end else begin
        NextState_SISt = READ_WT_LO;
      end
      next_streamSt = streamSt;
      next_txData = txData;
      next_rxData = rxData;
      next_writeEn = writeEn;
      next_dataOut = dataOut;
      next_bitCnt = bitCnt;
      next_clearStartStopDet = clearStartStopDet;
      next_regAddr = regAddr;
    end
    READ_WT_ACK: begin
      if (scl == 1'b1) begin
        NextState_SISt = CHK_RD_WR;
        if (sdaIn == `I2C_NAK) begin
          next_streamSt = `STREAM_IDLE;
        end else begin
          next_streamSt = streamSt;
        end
      end else begin
        NextState_SISt = READ_WT_ACK;
        next_streamSt = streamSt;
      end
      next_txData = txData;
      next_rxData = rxData;
      next_sdaOut = sdaOut;
      next_writeEn = writeEn;
      next_dataOut = dataOut;
      next_bitCnt = bitCnt;
      next_clearStartStopDet = clearStartStopDet;
      next_regAddr = regAddr;
    end
    WRITE_WT_LO: begin
     if (scl == 1'b0) begin
       if (startStopDetState == `START_DET) begin
          NextState_SISt = WRITE_ST_LOOP;
          next_streamSt = `STREAM_IDLE;
          next_rxData = 8'h00;
          next_bitCnt = bitCnt;
        end else begin
          NextState_SISt = WRITE_ST_LOOP;
          next_bitCnt = bitCnt + 3'b1;
          next_streamSt = streamSt;
          next_rxData = rxData;
          next_clearStartStopDet = clearStartStopDet;
        end
      end else begin
        NextState_SISt = WRITE_WT_LO;
        next_bitCnt = bitCnt;
        next_streamSt = streamSt;
        next_rxData = rxData;
      end
      next_sdaOut = sdaOut;
      next_writeEn = writeEn;
      next_dataOut = dataOut;
      next_txData = txData;
      next_regAddr = regAddr;
    end
    WRITE_WT_HI: begin
      if (scl == 1'b1) begin
        NextState_SISt = WRITE_WT_LO;
        next_rxData = {rxData[6:0], sdaIn};
        next_bitCnt = 3'b000;
      end else begin
        NextState_SISt = WRITE_WT_HI;
        next_rxData = rxData;
        next_bitCnt = bitCnt;
      end
      next_streamSt = streamSt;
      next_sdaOut = sdaOut;
      next_writeEn = writeEn;
      next_dataOut = dataOut;
      next_txData = txData;
      next_clearStartStopDet = clearStartStopDet;
      next_regAddr = regAddr;
    end
    WRITE_CHK_LOOP_FIN: begin
         if (bitCnt == 3'b111) begin
            NextState_SISt = WRITE_CLR_WR;
            next_sdaOut = `I2C_ACK;
            if (streamSt == `STREAM_IDLE) begin
               if (rxData[7:1] == `I2C_ADDRESS && startStopDetState == `START_DET) 
                 begin
                    if (rxData[0] == 1'b1)
                      next_streamSt = `STREAM_READ;
                    else
                      next_streamSt = `STREAM_WRITE_ADDR;
                 end
               else begin
                  next_sdaOut = `I2C_NAK;
                  next_streamSt = streamSt;
               end
            end
            else if (streamSt == `STREAM_WRITE_ADDR) begin
               next_streamSt = `STREAM_WRITE_DATA;
               next_regAddr = rxData;
            end
            else if (streamSt == `STREAM_WRITE_DATA) begin
               next_dataOut = rxData;
               next_writeEn = 1'b1;
               next_streamSt = streamSt;
            end 
            else begin
               next_streamSt = streamSt;
            end
         end 
         else begin
            NextState_SISt = WRITE_ST_LOOP;
            next_bitCnt = bitCnt + 3'b1;
            next_streamSt = streamSt;
            next_sdaOut = sdaOut;
         end
         next_txData = txData;
         next_rxData = rxData;
         next_clearStartStopDet = clearStartStopDet;
      end
    WRITE_LOOP_WT_LO: begin
      if (scl == 1'b0) begin
        NextState_SISt = WRITE_CHK_LOOP_FIN;
      end else begin
        NextState_SISt = WRITE_LOOP_WT_LO;
      end
      next_streamSt = streamSt;
      next_txData = txData;
      next_rxData = rxData;
      next_sdaOut = sdaOut;
      next_writeEn = writeEn;
      next_dataOut = dataOut;
      next_bitCnt = bitCnt;
      next_clearStartStopDet = clearStartStopDet;
      next_regAddr = regAddr;
    end
    WRITE_ST_LOOP: begin
      if (scl == 1'b1) begin
        NextState_SISt = WRITE_LOOP_WT_LO;
        next_rxData = {rxData[6:0], sdaIn};
      end else begin
        NextState_SISt = WRITE_ST_LOOP;
        next_rxData = rxData;
      end
      next_streamSt = streamSt;
      next_txData = txData;
      next_sdaOut = sdaOut;
      next_writeEn = writeEn;
      next_dataOut = dataOut;
      next_bitCnt = bitCnt;
      next_clearStartStopDet = clearStartStopDet;
      next_regAddr = regAddr;
    end
    WRITE_WT_LO2: begin
      if (scl == 1'b0) begin
        NextState_SISt = CHK_RD_WR;
        next_sdaOut = 1'b1;
      end else begin
        NextState_SISt = WRITE_WT_LO2;
      end
      next_streamSt = streamSt;
      next_txData = txData;
      next_rxData = rxData;
      next_writeEn = writeEn;
      next_dataOut = dataOut;
      next_bitCnt = bitCnt;
      next_clearStartStopDet = clearStartStopDet;
      next_regAddr = regAddr;
    end
    WRITE_WT_HI2: begin
      next_clearStartStopDet = 1'b0;
      if (scl == 1'b1) begin
        NextState_SISt = WRITE_WT_LO2;
      end else begin
        NextState_SISt = WRITE_WT_HI2;
      end
      next_streamSt = streamSt;
      next_txData = txData;
      next_rxData = rxData;
      next_sdaOut = sdaOut;
      next_writeEn = writeEn;
      next_dataOut = dataOut;
      next_bitCnt = bitCnt;
      next_regAddr = regAddr;
    end
    WRITE_CLR_WR: begin
      if (writeEn == 1'b1) begin
        next_regAddr = regAddr + 8'b1;
      end else begin
        next_regAddr = regAddr;
      end
      next_writeEn = 1'b0;
      next_clearStartStopDet = 1'b1;
      NextState_SISt = WRITE_WT_HI2;
      next_streamSt = streamSt;
      next_txData = txData;
      next_rxData = rxData;
      next_sdaOut = sdaOut;
      next_dataOut = dataOut;
      next_bitCnt = bitCnt;
    end
    default: begin
      NextState_SISt = START;
      next_streamSt = `STREAM_IDLE;
      next_txData = 8'h00;
      next_rxData = 8'h00;
      next_sdaOut = 1'b1;
      next_writeEn = 1'b0;
      next_dataOut = 8'h00;
      next_bitCnt = 3'b000;
      next_clearStartStopDet = 1'b0;
      next_regAddr = regAddr;
    end
  endcase
end

// Current State Logic (sequential)
always @ (posedge clk)
begin
  if (rst == 1'b1)
    CurrState_SISt <= START;
  else
    CurrState_SISt <= NextState_SISt;
end

// Registered outputs logic
always @ (posedge clk)
begin
  if (rst == 1'b1)
  begin
    sdaOut <= 1'b1;
    writeEn <= 1'b0;
    dataOut <= 8'h00;
    clearStartStopDet <= 1'b0;
    // regAddr <=     // Initialization in the reset state or default value required!!
    streamSt <= `STREAM_IDLE;
    txData <= 8'h00;
    rxData <= 8'h00;
    bitCnt <= 3'b000;
  end
  else 
  begin
    sdaOut <= next_sdaOut;
    writeEn <= next_writeEn;
    dataOut <= next_dataOut;
    clearStartStopDet <= next_clearStartStopDet;
    regAddr <= next_regAddr;
    streamSt <= next_streamSt;
    txData <= next_txData;
    rxData <= next_rxData;
    bitCnt <= next_bitCnt;
  end
end

endmodule