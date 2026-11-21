`timescale 1ns/1ps
// =============================================================
// Bo nhan tuan tu W x W bit (Shift-and-Add), giao tiep valid/ready
// Kien truc: FSM 3 trang thai (IDLE -> CALC -> DONE) + Datapath 4 thanh ghi
// =============================================================
module mul16 #(
    parameter int W = 16
) (
    input  logic             clk,
    input  logic             reset,       // Reset muc cao (doi thanh !rst_n neu dac ta dung muc thap)

    // Phia yeu cau (Request)
    input  logic             req_valid,
    output logic             req_ready,
    input  logic [W-1:0]     a,
    input  logic [W-1:0]     b,

    // Phia ket qua (Response)
    output logic             resp_valid,
    input  logic             resp_ready,
    output logic [2*W-1:0]   prod
);

    // =========================================================
    // 1. KHAI BAO TRANG THAI (FSM) & THANH GHI (DATAPATH)
    // =========================================================
    typedef enum logic [1:0] {
        S_IDLE = 2'b00,  // Cho du lieu dau vao (req_valid)
        S_CALC = 2'b01,  // Thuc hien nhan dich-cong trong W chu ky
        S_DONE = 2'b10   // Giu ket qua cho ben nhan (resp_ready)
    } state_t;

    state_t state, state_next;

    // 4 thanh ghi cua Datapath
    logic [2*W-1:0]     reg_a;    // So bi nhan (dich trai moi chu ky)
    logic [W-1:0]       reg_b;    // So nhan (dich phai moi chu ky)
    logic [2*W-1:0]     reg_acc;  // Thanh ghi tich luy ket qua
    logic [$clog2(W):0] reg_cnt;  // Bo dem so chu ky tinh toan (0 -> W-1)

    // Tin hieu dieu khien tu FSM sang Datapath
    logic do_load;  // Nap du lieu dau vao
    logic do_step;  // Thuc hien 1 buoc dich-cong

    // =========================================================
    // 2. KHOI DIEU KHIEN (FSM - CONTROLLER)
    // =========================================================

    // 2a. Thanh ghi trang thai (Sequential)
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
        end else begin
            state <= state_next;
        end
    end

    // 2b. Logic chuyen trang thai & tin hieu dieu khien (Combinational)
    always_comb begin
        // Gia tri mac dinh tranh tao Latch
        state_next = state;
        req_ready  = 1'b0;
        resp_valid = 1'b0;
        do_load    = 1'b0;
        do_step    = 1'b0;

        case (state)
            S_IDLE: begin
                req_ready = 1'b1; // San sang nhan phep nhan moi
                if (req_valid) begin
                    do_load    = 1'b1;
                    state_next = S_CALC;
                end
            end

            S_CALC: begin
                do_step = 1'b1;
                if (reg_cnt == W - 1) begin
                    state_next = S_DONE;
                end
            end

            S_DONE: begin
                resp_valid = 1'b1; // Bao ket qua da hop le
                if (resp_ready) begin
                    state_next = S_IDLE;
                end
            end

            default: begin
                state_next = S_IDLE;
            end
        endcase
    end

    // =========================================================
    // 3. KHOI XU LY DU LIEU (DATAPATH)
    // =========================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            reg_a   <= '0;
            reg_b   <= '0;
            reg_acc <= '0;
            reg_cnt <= '0;
        end else if (do_load) begin
            // Nap gia tri ban dau khi bat tay req_valid & req_ready
            reg_a   <= {{W{1'b0}}, a}; // Mo rong 0 len 2*W bit
            reg_b   <= b;
            reg_acc <= '0;
            reg_cnt <= '0;
        end else if (do_step) begin
            // Neu bit thap nhat cua b bang 1 thi cong a vao tich luy
            if (reg_b[0]) begin
                reg_acc <= reg_acc + reg_a;
            end
            // Dich bit cho chu ky tiep theo
            reg_a   <= reg_a << 1;
            reg_b   <= reg_b >> 1;
            reg_cnt <= reg_cnt + 1'b1;
        end
    end

    // =========================================================
    // 4. GAN NGO RA
    // =========================================================
    assign prod = reg_acc;

endmodule
