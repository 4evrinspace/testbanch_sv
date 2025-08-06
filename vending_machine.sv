

//Or should I make with parametr 
interface vending_machine(input bit clk, input bit rst_n );
   // Input
   struct packed{
     logic [31:0] regs_data_in;
     logic [31:0] regs_data_out;
     logic regs_we;
     logic [7:0] regs_addr;
   } data_in  
   

   struct packed {
       logic id_valid;
       logic [8:0] client_id;
       logic [5:0] coin_in;
       logic [1:0] currency_type;
       logic coin_insert;
       logic [30:0] item_select; // [04:00] num_items -> max(num_items) = 31
       logic confirm;
   } user_in;


   struct packed {
       logic admin_mode;
       logic [31:0] admin_password;
   } admin_in;

   struct packed {
       logic tamper_detect;
       logic jam_detect;
       logic power_loss;
   } security_in;


   //Output
   struct packed {
     logic access_error;
     logic [30:0] item_out; // [04:00] num_items -> max(num_items) = 31
     logic [5:0] change_out;
     logic no_change;
     logic [30:0] item_empty; // [04:00] num_items -> max(num_items) = 31
     logic [7:0] client_points;
     logic alarm;
     logic [2:0] state;
   } data_out

   clocking master_cb @ ( posedge clk );
      default input #1step output #1ns;
      output  data_in, user_in, admin_in, security_in;
      input data_out;
   endclocking: master_cb

   clocking slave_cb @ ( posedge clk );
      default input #1step output #1ns;
      input  data_in, user_in, admin_in, security_in;
      output data_out;
   endclocking: slave_cb
   
   modport master_mp (input clk, rst_n, output data_in, user_in, admin_in, security_in, input  data_out);

   modport slave_mp (input clk, rst_n, input  data_in, user_in, admin_in, security_in, output data_out);

   modport master_sync_mp (clocking master_cb);
   modport slave_sync_mp (clocking slave_cb, input rst_n);
 endinterface: jelly_bean_if


package machine_env;
   import uvm_pkg::*;
   `include "uvm_macros.svh"
    function random_range(int range_start = 0, int range_end = 1);
      int value;
      std::randomize(value) with {range_start <= value; value <= range_end; };
      return value;
    endfunction: random_range
  

  class vending_machine_configuration extends uvm_object;
   `uvm_object_utils( vending_machine_configuration )

    function new( string name = "" );
      super.new( name );
    endfunction: new
  endclass: vending_machine_configuration

  class buying_transaction extends uvm_sequence_item;
    
  endclass buying_transaction;
endpackage: machine_env

