% =========================================================================
% This script processes experimental data from the 'datanarrative' table.
% It extracts beliefs and signal histories for each participant and 
% separates them by experimental treatment: Control vs Narrative.
% =========================================================================

% === Extract relevant columns from the raw table ===
ids = datanarrative.id;            % Unique subject identifiers
treatments = datanarrative.treatment;  % Treatment assignment: 'Control' or 'Narratives'
beliefs = datanarrative.belief;        % Belief reported in each round (11 rounds)
signals = datanarrative.sign;          % Signal observed in each round (10 signals, round 0 has none)
rounds = datanarrative.round;          % Round number (0 to 10)

% === Get list of unique subjects ===
unique_ids = unique(ids);

% === Initialize containers for beliefs and signals ===
control_beliefs = [];
control_signals = [];
treatment_beliefs = [];
treatment_signals = [];

% === Loop over participants ===
for i = 1:length(unique_ids)
    this_id = unique_ids(i);

    % Select all rows corresponding to this participant
    rows = ids == this_id;

    % Retrieve treatment assignment (should be constant for each subject)
    this_treatment = treatments(find(rows, 1));

    % Extract full belief vector (11 rounds)
    this_beliefs = beliefs(rows);

    % Extract signals (excluding round 0, which has no signal)
    this_signals = signals(rows);
    this_rounds = rounds(rows);
    this_signals = this_signals(this_rounds ~= 0);  % Keep only rounds 1–10

    % Sanity check: keep only subjects with complete data (11 beliefs, 10 signals)
    if length(this_beliefs) == 11 && length(this_signals) == 10
        if this_treatment == "Control"
            control_beliefs(end+1, :) = this_beliefs';
            control_signals(end+1, :) = this_signals';
        elseif this_treatment == "Narratives"
            treatment_beliefs(end+1, :) = this_beliefs';
            treatment_signals(end+1, :) = this_signals';
        end
    end
end

% === Combine beliefs and signals into matrices for export and analysis ===
control_matrix = [control_beliefs, control_signals];
treatment_matrix = [treatment_beliefs, treatment_signals];

% === Display matrix dimensions (rows = participants) ===
disp("Control matrix size:");
disp(size(control_matrix));
disp("Treatment matrix size:");
disp(size(treatment_matrix));

% === Optional: Export data for further analysis (e.g., bootstrap, modeling) ===
writematrix(control_matrix, 'control_matrix.csv');
writematrix(treatment_matrix, 'treatment_matrix.csv');

% === Split into early and late rounds for separate analysis ===
% First 5 rounds: beliefs 1–6 (0 to 5), signals 1–5
control_first5 = [control_matrix(:, 1:6), control_matrix(:, 12:16)];
treatment_first5 = [treatment_matrix(:, 1:6), treatment_matrix(:, 12:16)];

% Second 5 rounds: beliefs 6–11 (5 to 10), signals 6–10
control_second5 = [control_matrix(:, 6:11), control_matrix(:, 17:21)];
treatment_second5 = [treatment_matrix(:, 6:11), treatment_matrix(:, 17:21)];
