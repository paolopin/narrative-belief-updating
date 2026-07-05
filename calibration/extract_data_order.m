% =========================================================================
% This script preprocesses belief and signal data from 'datanarrative'
% by centering beliefs and flipping signal signs for subjects with prior > 0.5.
% This transformation is used to standardize belief trajectories across subjects,
% allowing comparison of updating behavior relative to their initial beliefs.
%
% Reference: See "Bootstrap_draft.pdf", Section 'Signal-Conditional Belief Dynamics'.
% =========================================================================

% === Extract relevant variables from the table ===
ids = datanarrative.id;                % Subject IDs
treatments = datanarrative.treatment; % Treatment group (Control or Narratives)
beliefs = datanarrative.belief;       % Belief reports (rounds 0–10)
signals = datanarrative.sign;         % Observed signals (rounds 1–10)
rounds = datanarrative.round;         % Round number (0–10)

% === List of unique subjects ===
unique_ids = unique(ids);

% === Initialize matrices for preprocessed data ===
control_matrix = [];
treatment_matrix = [];

% === Loop over each subject ===
for i = 1:length(unique_ids)
    this_id = unique_ids(i);
    
    % Select all rows for this subject
    rows = ids == this_id;
    
    % Retrieve treatment assignment
    this_treatment = treatments(find(rows, 1, 'first'));
    
    % Extract belief trajectory and signals
    this_beliefs = beliefs(rows);             % Should contain 11 values
    this_signals = signals(rows);
    this_rounds = rounds(rows);
    
    % Remove signal from round 0 (which is undefined)
    filtered_signals = this_signals(this_rounds ~= 0);  % Should contain 10 values

    % Sanity check: must have full sequence
    if length(this_beliefs) == 11 && length(filtered_signals) == 10
        
        % === Normalize based on initial belief ===
        if this_beliefs(1) > 0.5
            % Flip beliefs symmetrically around 0.5
            this_beliefs = 1 - this_beliefs;
            
            % Flip signal direction, preserving 0 as neutral
            filtered_signals = arrayfun(@(x) -x * (x ~= 0), filtered_signals);
        end

        % === Combine beliefs and signals into a row vector ===
        % [belief_0 ... belief_10, signal_1 ... signal_10]
        data_row = [this_beliefs', filtered_signals'];

        % === Assign to corresponding matrix ===
        if this_treatment == "Control"
            control_matrix(end+1, :) = data_row;
        elseif this_treatment == "Narratives"
            treatment_matrix(end+1, :) = data_row;
        end
    end
end

% === Print matrix sizes ===
disp("Control matrix size:");
disp(size(control_matrix));
disp("Treatment matrix size:");
disp(size(treatment_matrix));

% === Optional: export data for further analysis (e.g., bootstrap estimation) ===
writematrix(control_matrix, 'control_matrix.csv');
writematrix(treatment_matrix, 'treatment_matrix.csv');

% === Create matrices for first and second halves ===
% First 5 rounds: beliefs 1–6 (col 1–6), signals 1–5 (col 12–16)
control_first5 = [control_matrix(:, 1:6), control_matrix(:, 12:16)];
treatment_first5 = [treatment_matrix(:, 1:6), treatment_matrix(:, 12:16)];

% Second 5 rounds: beliefs 6–11 (col 6–11), signals 6–10 (col 17–21)
control_second5 = [control_matrix(:, 6:11), control_matrix(:, 17:21)];
treatment_second5 = [treatment_matrix(:, 6:11), treatment_matrix(:, 17:21)];
