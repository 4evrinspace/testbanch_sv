

    interface data_in_if(input bit clk, input bit rst_n );
        logic [31:0] regs_data_in;
        logic regs_we;
        logic [7:0] regs_addr;
    endinterface

    interface user_in_if(input bit clk, input bit rst_n );
        logic [8:0] client_id;
        logic [5:0] coin_in;
        logic [1:0] currency_type;
        logic [9:0] item_select; 
        logic [9:0] item_out; 
        logic [5:0] change_out;
        logic no_change;
        logic [9:0] item_empty; 
        logic [7:0] client_points;
        logic done;
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
        logic alarm;
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

        class change_data_in_item  extends uvm_sequence_item;;
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

        class item_buy_item extends uvm_sequence_item;
            logic [8:0] client_id;
            typedef struct {
                money_type cur;
                logic [5:0] value;
            } coin_s;
            coin_s coins[$];
            logic [30:0] item_select; 
            logic [31:0] change_out 
            logic [9:0] item_out
            logic [7:0] client_points 
            
            
            function new( string name = "" );
                super.new( name );
                this.m_random();
            endfunction

            function void m_random();

                client_id = random_range(0,  ~9'd0);
                item_select  = (9'd1) << random_range(0, 8);
                coins.delete();
                int num_coins = random_range(0, 10);    
                for (int i = 0; i < num_coins; i++) begin
                    coin_s c;
                    c.cur = money_type'($urandom_range(0,2));
                    c.value = random_range(0,  ~6'd0);;
                    coins.push_back(c);
                end
            endfunction: m_random

        `uvm_object_utils_begin(item_buy_seq)
            `uvm_field_int(client_id    , UVM_ALL_ON)
            `uvm_field_int(coin_in      , UVM_ALL_ON)
            `uvm_field_enum(money_type, currency_type, UVM_ALL_ON)
            `uvm_field_int(item_select  , UVM_ALL_ON)
            `uvm_field_queue_int(coins, UVM_ALL_ON)
        `uvm_object_utils_end

        endclass


        class one_item_buy_seq extends uvm_sequence#( item_buy_item);
            `uvm_object_utils( one_item_buy_seq )

            function new( string name = "" );
                super.new( name );
            endfunction: new

            task body();
                item_buy_item item_tx;
                item_tx = item_buy_item::type_id::create( .name( "item_tx" ) );
                start_item( item_tx );
                item_tx.m_random();
                finish_item( item_tx );
            endtask: body
        endclass

        class many_item_buy_seq extends uvm_sequence#(item_buy_item);
            int unsigned item_num;
            constraint num_item { item_num inside {[0:10]}; }

            `uvm_object_utils_begin(many_item_buy_seq)
                `uvm_field_int(item_num, UVM_ALL_ON)
            `uvm_object_utils_end

            function new(string name = "many_item_buy_seq");
                super.new(name);
            endfunction

            task body();
                repeat(item_num) begin
                    item_buy_item tx = item_buy_item::type_id::create(.name( "item_tx" ));
                    start_item(tx);
                    assert(tx.randomize());
                    finish_item(tx);
                end
            endtask
        endclass

        class user_driver extends uvm_driver#(item_buy_item);
            `uvm_component_utils(user_driver)
            virtual user_in_if vif;

            function new(string name, uvm_component parent=null);
                super.new(name, parent);
            endfunction

            function void build_phase(uvm_phase phase);
                if(!uvm_config_db#(virtual user_in_if)::get(this, "", "vif", vif))
                `   uvm_fatal("DRV", "No vif for user_driver")
            endfunction

            task run_phase(uvm_phase phase);
                forever begin
                    item_buy_item tx;
                    seq_item_port.get_next_item(tx);
                    @(posedge vif.clk);
                    vif.client_id     <= tx.client_id;
                    vif.item_select   <= tx.item_select;
                    foreach (tx.coins[i]) begin
                        @(posedge vif.clk);
                        vif.currency_type <= tx.coins[i].cur;
                        vif.coin_in       <= tx.coins[i].value;
                    end
                end
                @(posedge vif.clk);
                    vif.done <= '1;

            endtask
        endclass
        
        class user_monitor extends uvm_monitor;
            `uvm_component_utils(user_monitor)

            virtual user_in_if vif;
            uvm_analysis_port#(item_buy_item) ap;

            function new(string name, uvm_component parent=null);
                super.new(name, parent);
            endfunction

            function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                ap = new("ap", this);
                if(!uvm_config_db#(virtual user_in_if)::get(this, "", "vif", vif))
                    `uvm_fatal("MON", "No vif for user_monitor")
            endfunction

            task run_phase(uvm_phase phase);
                forever begin
                item_buy_item tx = item_buy_item::type_id::create("item_tx", this);

                
                @(posedge vif.clk iff vif.client_id != 0 || vif.item_select != 0);

                tx.client_id   = vif.client_id;
                tx.item_select = vif.item_select;

            
                tx.coins.delete();
                while (vif.done != 1) begin
                    item_buy_item::coin_s coin;
                    c.cur = money_type'(vif.currency_type);
                    c.value = vif.coin_in;

                    if (c.value != 0) begin
                        tx.coins.push_back(c);
                    end
                    @(posedge vif.clk);
                end 

            ap.write(tx);

                end
            endtask
        endclass

        class vm_scoreboard extends uvm_scoreboard;
            `uvm_component_utils(vm_scoreboard)

            uvm_analysis_export#(item_buy) exp_mon;
            uvm_analysis_export#(item_buy) got_mon;

            mailbox #(item_buy) exp_mb, got_mb; // ? 

            function new(string name, uvm_component parent=null);
                super.new(name, parent);
                exp_mb = new();
                got_mb = new();
            endfunction

            function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                exp_mon = new("exp_mon", this);
                got_mon = new("got_mon", this);
            endfunction

            task run_phase(uvm_phase phase);
                item_buy exp, got;
                forever begin
                    exp_mb.get(exp);
                    got_mb.get(got);

                    if (compare(exp, got))
                        `uvm_info("SCOREBOARD", $sformatf("PASS: %s", got.convert2string()), UVM_LOW)
                    else
                        `uvm_error("SCOREBOARD", $sformatf("FAIL exp=%s got=%s", 
                                exp.convert2string(), got.convert2string()))
                end
            endtask

            function bit compare(item_buy exp, item_buy got);
            // ПОка просто проверяем что пришло 
                if (exp.client_id    != got.client_id)    
                    return 0;
                if (exp.item_select  != got.item_select)  
                    return 0;
                if (exp.coins.size() != got.coins.size()) 
                    return 0;
                for (int i = 0; i < exp.coins.size(); i++) begin
                    if (exp.coins[i].cur   != got.coins[i].cur)   
                        return 0;
                    if (exp.coins[i].value != got.coins[i].value) 
                        return 0;
                end
                return 1;
            endfunction

        endclass

        class vm_agent extends uvm_agent;
            `uvm_component_utils(vm_agent)

            vm_driver    drv;
            vm_monitor   mon;
            uvm_sequencer#(item_buy) seqr;

            virtual user_in_if vif;

            function new(string name, uvm_component parent=null);
                super.new(name, parent);
            endfunction

            function void build_phase(uvm_phase phase);
                super.build_phase(phase);

                if (is_active == UVM_ACTIVE) begin
                    seqr = uvm_sequencer#(item_buy)::type_id::create("seqr", this);
                    drv = vm_driver::type_id::create("drv", this);
                end
                mon = vm_monitor::type_id::create("mon", this);

                if(!uvm_config_db#(virtual user_in_if)::get(this, "", "vif", vif))
                    `uvm_fatal("AGENT", "No vif connected!")

                if (drv) 
                    drv.vif = vif;
                if (mon) 
                    mon.vif = vif;
            endfunction

            function void connect_phase(uvm_phase phase);
                if (drv && seqr)
                    drv.seq_item_port.connect(seqr.seq_item_export);
            endfunction
        endclass

        class vm_env extends uvm_env;
            `uvm_component_utils(vm_env)

            vm_agent       agent;
            vm_scoreboard  scb;

            function new(string name, uvm_component parent=null);
                super.new(name, parent);
            endfunction

            function void build_phase(uvm_phase phase);
                super.build_phase(phase);

                agent = vm_agent::type_id::create("agent", this);
                scb   = vm_scoreboard::type_id::create("scb", this);
            endfunction

            function void connect_phase(uvm_phase phase);
                agent.mon.ap.connect(scb.got_mon);
            endfunction
        endclass

        class base_test extends uvm_test;
            `uvm_component_utils(base_test)

            vm_env env;

            function new(string name, uvm_component parent=null);
                super.new(name, parent);
            endfunction

            function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                env = vm_env::type_id::create("env", this);
            endfunction
            // ? 
            task run_phase(uvm_phase phase);
                item_buy item_tx;

                phase.raise_objection(this);

                one_item_buy_seq one_seq;
                one_seq = one_item_buy_seq::type_id::create("one_seq");
                one_seq.start(env.agent.seqr);
                #100ns;

                phase.drop_objection(this);
            endtask
        endclass
    endpackage 
    





    