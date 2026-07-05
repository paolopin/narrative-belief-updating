function compare_first_guess(control_matrix, treatment_matrix, B)
% =========================================================================
% COMPARE_FIRST_GUESS
%
% This function compares the *polarization* of initial beliefs (round 1)
% across Control and Narrative (Treatment) groups.
% It visualizes the absolute distance from 0.5 (epistemic neutrality)
% and performs a bootstrap test for the difference in mean distances.
%
% Used to generate **Figure 2** in the analysis (see Bootstrap_draft.pdf).
%
% INPUTS:
%   control_matrix    : [N x 21] matrix, beliefs in column 1 (round 1)
%   treatment_matrix  : [M x 21] matrix, beliefs in column 1 (round 1)
%   B (optional)      : number of bootstrap iterations (default: 1e5)
% =========================================================================

    if nargin < 3
        B = 1e5;  % Default number of bootstrap iterations
    end

    % === Step 1: Compute |Initial Belief - 0.5| for each subject ===
    dist_ctrl = abs(control_matrix(:, 1) - 0.5);    % Control group
    dist_treat = abs(treatment_matrix(:, 1) - 0.5); % Narrative group

    % === Step 2: Plot overlapping histograms of belief distances ===
    figure('Name', 'Initial Belief Distance from 0.5', 'Color', 'w');
    histogram(dist_ctrl, 'BinWidth', 0.05, ...
        'FaceColor', [0.2 0.6 0.8], 'FaceAlpha', 0.6);
    hold on;
    histogram(dist_treat, 'BinWidth', 0.05, ...
        'FaceColor', [0.9 0.4 0.4], 'FaceAlpha', 0.6);
    legend('Control', 'Narratives');
    xlabel('|Initial Belief - 0.5|');
    ylabel('Frequency');
    title('Initial Belief Distance from 0.5: Control vs. Treatment');
    grid on;

    % === Step 3: Two-sided bootstrap test for mean difference ===
    n_c = length(dist_ctrl);
    n_t = length(dist_treat);
    obs_diff = mean(dist_ctrl) - mean(dist_treat);  % Observed difference

    boot_diffs = zeros(B, 1);
    for b = 1:B
        sample_c = dist_ctrl(randi(n_c, n_c, 1));
        sample_t = dist_treat(randi(n_t, n_t, 1));
        boot_diffs(b) = mean(sample_c) - mean(sample_t);
    end

    % === Step 4: Compute two-sided p-value ===
    p_val = 2 * min(mean(boot_diffs <= obs_diff), mean(boot_diffs >= obs_diff));

    % === Step 5: Report results ===
    fprintf('\n--- Bootstrap Test: Initial Belief Polarization ---\n');
    fprintf('Mean |belief - 0.5| (Control)   : %.4f\n', mean(dist_ctrl));
    fprintf('Mean |belief - 0.5| (Narratives): %.4f\n', mean(dist_treat));
    fprintf('Observed mean difference        : %.4f\n', obs_diff);
    fprintf('Two-sided bootstrap p-value     : %.5f\n', p_val);
end
