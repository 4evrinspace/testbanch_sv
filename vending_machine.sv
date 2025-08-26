
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
        logic confirmed;
        logic coin_inserted;
        logic id_valid
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

        class item_buy_item extends uvm_sequence_item;
            int client_id;
            typedef struct {
                money_type cur;
                logic [5:0] value;
            } coin_s;
            coin_s coins[$];
            int item_selected; 
            logic [31:0] change_out 
            logic [9:0] item_out
            logic [7:0] client_points 
            
            
            function new( string name = "" );
                super.new( name );
                this.m_random();
            endfunction

            function void m_random();
                int num_coins = random_range(1, 10); 
                coin_s c;
                client_id = random_range(0,  9);
                item_selected  = random_range(0, 9);
                coins.delete();
                   
                for (int i = 0; i < num_coins; i++) begin
                    
                    c.cur = money_type'($urandom_range(0,2));
                    c.value = random_range(0,  ~6'd0);;
                    coins.push_back(c);
                end
            endfunction: m_random

        `uvm_object_utils_begin(item_buy_seq)
            `uvm_field_int(client_id, UVM_ALL_ON)
            `uvm_field_enum(money_type, currency_type, UVM_ALL_ON)
            `uvm_field_int(item_selected  , UVM_ALL_ON)
            `uvm_field_int(change_out, UVM_ALL_ON)
            `uvm_field_int(item_out, UVM_ALL_ON)
            `uvm_field_int(client_points, UVM_ALL_ON)
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
                    tx.m_random();
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

                    vif.client_id <= tx.client_id;
                    vif.id_valid <= 1;
                    
                    foreach (tx.coins[i]) begin
                        @(posedge vif.clk);
                        vif.currency_type <= tx.coins[i].cur;
                        vif.coin_in <= tx.coins[i].value;
                        vif.coin_inserted <= 1; 
                    end
                    @(posedge vif.clk);
                    vif.item_select <= (10'b1 << tx.item_selected); 
                    vif.coin_inserted <= 0;
                    vif.confirmed <= 1;
                end


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

                    
                    @(posedge vif.clk iff vif.id_valid == 1);

                    tx.client_id   = vif.client_id;
                    

                
                    tx.coins.delete();
                    while (!vif.confirmed) begin
                        item_buy_item::coin_s coin;
                        @(posedge vif.clk iff vif.coin_insert == 1);
                        c.cur = money_type'(vif.currency_type);
                        c.value = vif.coin_in;
                        tx.coins.push_back(c);
                    end 
                    tx.item_selected = $clog2(vif.item_select);
                    tx.client_points = vif.client_points;
                    ap.write(tx);

                end
            endtask
        endclass

        class vm_scoreboard extends uvm_scoreboard;
            `uvm_component_utils(vm_scoreboard)

            uvm_analysis_imp#(item_buy_item, vm_scoreboard) imp;

            function new(string name, uvm_component parent=null);
                super.new(name, parent);
            endfunction

            function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                imp = new("imp", this);
            endfunction

            function void write(item_buy_item tx);
                int money = 0;
                foreach (tx.coins[i]) begin
                    money += tx.coins[i].value;
                end

                price = tx.item_selected * 10;
                int change = 0;
                int exp_item_out;
                int exp_points;
                int discount = tx.client_id % 3;
                if (tx.client_id % 10 == 0) discount += 10;
                price = price * (100.0 - discount) / 100.0;
                if (sum >= price) begin
                    exp_item_out = 10'b1 << tx.item_selected;
                    change = sum - price;
                    exp_points = sum / 20; 
                end else begin
                    exp_item_out = '0;
                    change       = sum;
                    exp_points   = 0;
                end

                `uvm_info("SCOREBOARD",
                        $sformatf("Client=%0d Item=%0d Sum=%0d Exp_item_out=%b Exp_change=%0d Exp_points=%0d",
                                    tx.client_id, tx.item_selected, sum, exp_item_out, change, exp_points),
                        UVM_LOW)
            endfunction

    endclass

        class vm_agent extends uvm_agent;
            `uvm_component_utils(vm_agent)

            vm_driver drv;
            vm_monitor mon;
            uvm_sequencer#(item_buy_item) seqr;

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

            vm_agent agent;
            vm_scoreboard scb;

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

        //Любой тест наследуется от этого 
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
    
// top - подключение dut инициализация передача интерфейса в агент настройка rst clk вызывать функцию run_test 

class buy_test extends base_test;
    `uvm_component_utils(discount_test)

    function new(string name, uvm_component parent=null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        many_item_buy_seq seq;
        seq = many_item_buy_seq::type_id::create("seq");
        seq.item_num = 5;  
        seq.start(env.agent.seqr);

        #200ns;
        phase.drop_objection(this);
    endtask
endclass



module top;
    import uvm_pkg::*;
    import vending_machine::*;

    bit clk;
    bit rst_n;

    user_in_if uif(.clk(clk), .rst_n(rst_n));

    initial forever #5 clk = ~clk;

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;

        uvm_config_db#(virtual user_in_if)::set(null, "*", "vif", uif);
        run_test("base_test");
    end
endmodule



    