

interface data_in_if(input bit clk, input bit rst_n );
     logic [31:0] regs_data_in;
     logic regs_we;
     logic [7:0] regs_addr;
endinterface

interface user_in_if(input bit clk, input bit rst_n );
    logic [8:0] client_id;
    logic [5:0] coin_in;
    logic [1:0] currency_type;
    logic [30:0] item_select; // [04:00] num_items -> max(num_items) = 31
endinterface

interface admin_in_if(input bit clk, input bit rst_n );
    logic [31:0] admin_password;
endinterface

interface security_in_if(input bit clk, input bit rst_n );
    logic tamper_detect;
    logic jam_detect;
    logic power_loss;
endinterface

interface data_out_if(input bit clk, input bit rst_n );
     logic access_error;
     logic [30:0] item_out; // [04:00] num_items -> max(num_items) = 31
     logic [5:0] change_out;
     logic no_change;
     logic [30:0] item_empty; // [04:00] num_items -> max(num_items) = 31
     logic [7:0] client_points;
     logic alarm;
     logic [2:0] state;
endinterface


package vending_machine
    import uvm_pkg::*;
    include "uvm_macros.svh";
    function random_range(int range_start = 0, int range_end = 1);
      int value;
      std::randomize(value) with {range_start <= value; value <= range_end; };
      return value;
    endfunction

    typedef enum {CUR_RUB=2'b00, CUR_USD=2'b01, CUR_EUR=2'b10} money_type;

    class change_data_in  extends uvm_sequence_item;;
        logic [31:0] regs_data_in;
        logic [31:0] regs_data_out;
        logic regs_we;
        logic [7:0] regs_addr;

        `uvm_object_utils_begin(change_data_in)
            `uvm_field_int(regs_data_in , UVM_ALL_ON)
            `uvm_field_int(regs_we , UVM_ALL_ON)
            `uvm_field_int(regs_addr, UVM_ALL_ON)
            `uvm_field_int(regs_data_out, UVM_DEFAULT)
        `uvm_object_utils_end
        function new(string name = "change_data_in");
            super.new(name);
        endfunction

        function void randomize();
            regs_data_in = random_range(0, ~32'd0); 
            regs_we = random_range(0, 1);
            regs_addr = random_range(0, ~8'd0);
        endfunction

    endclass  

    class item_buy_seq extends uvm_sequence_item;
        logic [8:0] client_id;
        logic [5:0] coin_in;
        money_type currency_type;
        logic [30:0] item_select; // constraints on super class (?) or in .svh
        function new( string name = "" );
            super.new( name );
            this.m_random();
        endfunction

        function void m_random();
            client_id = random_range(0,  ~9'd0); 
            coin_in = random_range(0,  ~5'd0); 
            currency_type = money_type'(random_range(0, 2)); 
            item_select  = (31'd1) << random_range(0, 30);
        endfunction: m_random

      `uvm_object_utils_begin(item_buy_seq)
        `uvm_field_int(client_id    , UVM_ALL_ON)
        `uvm_field_int(coin_in      , UVM_ALL_ON)
        `uvm_field_enum(money_type, currency_type, UVM_ALL_ON)
        `uvm_field_int(item_select  , UVM_ALL_ON)
      `uvm_object_utils_end

    endclass


    class one_item_buy_seq extends uvm_sequence#( item_buy_seq );
      `uvm_object_utils( one_item_buy_seq  )

      function new( string name = "" );
          super.new( name );
      endfunction: new

      task body();
          item_buy_seq item_tx;
          item_tx = item_buy_seq::type_id::create( .name( "item_tx" ) );
          start_item( item_tx );
          item_tx.m_random();
          finish_item( item_tx );
      endtask: body
    endclass: one_jelly_bean_sequence

    class many_item_buy_seq extends one_item_buy_seq; // or extends uvm_sequence#(one_item_buy_seq)
        int unsigned item_num; // или в task body все генерировать

      `uvm_object_utils_begin( many_item_buy_seq )
          `uvm_field_int( item_num, UVM_ALL_ON )
      `uvm_object_utils_end
    endclass


      
endpackage 
  