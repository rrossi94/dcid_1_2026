//////////////////////////////////////////////////////////////////////
////                                                              ////
//// i2cSlave_tristate.v                                          ////
////                                                              ////
//// This file is part of the i2cSlave opencores effort.          ////
////                                                              ////
//// Module Description:                                          ////
//// Tri-state buffer for SDA bus, separated from main i2cSlave   ////
//// logic to comply with lint rules (TSMHOL).                    ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
module i2cSlave_tristate (
  inout  sda,
  input  sdaOut,
  output sdaIn
);

assign sda   = (sdaOut == 1'b0) ? 1'b0 : 1'bz;
assign sdaIn = sda;

endmodule
