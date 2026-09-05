// ---------------------------------- testcase0.v ----------------------------
`include "i2cSlave_define.v"
`include "i2cSlaveTB_defines.v"

module testCase0();

reg ack;
reg [7:0] data;
reg [15:0] dataWord;
reg [7:0] dataRead;
reg [7:0] dataWrite;
integer i;
integer j;

// Función para comparar señal con valor esperado
task check_signal;
  input [7:0] signal;       // Señal a comparar
  input [7:0] expected;     // Valor esperado
  begin
      if (signal === expected) begin
        $display("Tiempo %0t: OK: es igual a 0x%h", $time, expected);
      end else begin
        $display("Tiempo %0t: ERROR: no es igual a 0x%h, valor actual = 0x%h", $time, expected, signal);
        $stop;             // Detener simulación
      end
  end
endtask

initial
begin
  $write("\n\n");
  testHarness.reset;
  #1000;

  // Configuracion del entorno
  //   set i2c master clock scale reg PRER = (48MHz / (5 * 400KHz) ) - 1
  $write("Testing register read/write\n");
  testHarness.u_wb_master_model.wb_write(1, `PRER_LO_REG , 8'h17);
  testHarness.u_wb_master_model.wb_write(1, `PRER_HI_REG , 8'h00);
  testHarness.u_wb_master_model.wb_cmp(1, `PRER_LO_REG , 8'h17);

  //  enable i2c master
  testHarness.u_wb_master_model.wb_write(1, `CTR_REG , 8'h80);

  // Test 
  multiByteReadWrite.write({`I2C_ADDRESS, 1'b0}, 8'h00, 32'h89abcdef, `SEND_STOP);
  check_signal(testHarness.u_i2cSlave.myReg0,8'h89);
  check_signal(testHarness.u_i2cSlave.myReg1,8'hab);
  check_signal(testHarness.u_i2cSlave.myReg2,8'hcd);
  check_signal(testHarness.u_i2cSlave.myReg3,8'hef);

  // Ejemplo lectura
  //multiByteReadWrite.read({`I2C_ADDRESS, 1'b0}, 8'h00, 32'h89abcdef, dataWord, `NULL);

  $write("Finished all tests\n");
  $stop;	

end

endmodule

