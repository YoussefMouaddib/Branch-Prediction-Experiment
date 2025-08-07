`timescale 1ns / 1ps

module HybridBranchPredictor #(
    parameter GHR_BITS = 8,
    parameter PHT_BITS = 10  // 1024 entries
)(
    input wire clk,
    input wire reset,
    input wire [31:0] pc,
    input wire is_branch,
    input wire branch_taken, // Actual outcome (for training)
    input wire branch_valid, // When actual outcome is known
    output wire prediction
);

    // Global History Register
    reg [GHR_BITS-1:0] ghr;

    // GShare Pattern History Table (2-bit saturating counters)
    reg [1:0] gshare_pht [0:(1<<PHT_BITS)-1];

    // Bimodal Table (also 2-bit counters)
    reg [1:0] bimodal_pht [0:(1<<PHT_BITS)-1];

    // Selector Table (2-bit counters)
    reg [1:0] selector_table [0:(1<<PHT_BITS)-1];

    wire [PHT_BITS-1:0] gshare_index = (pc[11:2] ^ ghr);
    wire [PHT_BITS-1:0] bimodal_index = pc[11:2];
    wire [PHT_BITS-1:0] selector_index = pc[11:2];

    wire gshare_prediction = gshare_pht[gshare_index][1];
    wire bimodal_prediction = bimodal_pht[bimodal_index][1];
    wire use_gshare = selector_table[selector_index][1];

    assign prediction = use_gshare ? gshare_prediction : bimodal_prediction;

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            ghr <= 0;
            for (i = 0; i < (1<<PHT_BITS); i = i + 1) begin
                gshare_pht[i] <= 2'b01;
                bimodal_pht[i] <= 2'b01;
                selector_table[i] <= 2'b01;
            end
        end else if (branch_valid && is_branch) begin
            // Update GShare predictor
            if (branch_taken) begin
                if (gshare_pht[gshare_index] != 2'b11)
                    gshare_pht[gshare_index] <= gshare_pht[gshare_index] + 1;
            end else begin
                if (gshare_pht[gshare_index] != 2'b00)
                    gshare_pht[gshare_index] <= gshare_pht[gshare_index] - 1;
            end

            // Update Bimodal predictor
            if (branch_taken) begin
                if (bimodal_pht[bimodal_index] != 2'b11)
                    bimodal_pht[bimodal_index] <= bimodal_pht[bimodal_index] + 1;
            end else begin
                if (bimodal_pht[bimodal_index] != 2'b00)
                    bimodal_pht[bimodal_index] <= bimodal_pht[bimodal_index] - 1;
            end

            // Update selector
            if (gshare_prediction != bimodal_prediction) begin
                if (gshare_prediction == branch_taken && selector_table[selector_index] != 2'b11)
                    selector_table[selector_index] <= selector_table[selector_index] + 1;
                else if (bimodal_prediction == branch_taken && selector_table[selector_index] != 2'b00)
                    selector_table[selector_index] <= selector_table[selector_index] - 1;
            end

            // Update GHR
            ghr <= {ghr[GHR_BITS-2:0], branch_taken};
        end
    end

endmodule
