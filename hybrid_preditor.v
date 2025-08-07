module hybrid_predictor (
    input clk,
    input reset,

    // Prediction phase
    input [31:0] pc_in,
    output reg prediction,

    // Update phase
    input update_en,
    input [31:0] update_pc,
    input actual_taken
);
// Sub-predictors
wire bimodal_prediction;
wire gshare_prediction;

reg [1:0] selector_table [0:1023];
wire [9:0] index = pc_in[11:2];
wire select = selector_table[index][1]; // MSB decides predictor

// Connect submodules
bimodal_predictor bimodal_inst (
    .pc_in(pc_in),
    .prediction(bimodal_prediction),
    ...
);

gshare_predictor gshare_inst (
    .pc_in(pc_in),
    .prediction(gshare_prediction),
    ...
);
always @(*) begin
    prediction = select ? gshare_prediction : bimodal_prediction;
end
always @(posedge clk) begin
    if (reset) begin
        integer i;
        for (i = 0; i < 1024; i = i + 1)
            selector_table[i] <= 2'b01; // Bias toward bimodal
    end
    else if (update_en) begin
        // Get actual predictions from both predictors
        wire bimodal_correct = (bimodal_prediction == actual_taken);
        wire gshare_correct = (gshare_prediction == actual_taken);

        // Update selector table
        if (bimodal_correct != gshare_correct) begin
            if (gshare_correct && selector_table[index] != 2'b11)
                selector_table[index] <= selector_table[index] + 1;
            else if (bimodal_correct && selector_table[index] != 2'b00)
                selector_table[index] <= selector_table[index] - 1;
        end
    end
end
