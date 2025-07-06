function boxchart_initial_final(control_matrix, treatment_matrix)
% =========================================================================
% This function plots initial and final belief distributions (rounds 1 and 11)
% for Control and Narrative (Treatment) groups as boxplots, and runs a
% one-sided bootstrap test to assess whether the Control group has higher
% average beliefs than the Treatment group at each time point.
%
% Used to generate **Figure 1** in the analysis (see Bootstrap_draft.pdf).
% =========================================================================

    % === Extract beliefs from round 1 (column 1) and round 11 (column 11) ===
    control_first = control_matrix(:, 1);    % Beliefs at round 1 (prior)
    control_last  = control_matrix(:, 11);   % Beliefs at round 11 (posterior)
    treat_first   = treatment_matrix(:, 1);
    treat_last    = treatment_matrix(:, 11);

    n_c = size(control_matrix, 1);  % Number of subjects in Control
    n_t = size(treatment_matrix, 1);  % Number of subjects in Narratives

    % === Setup for display and testing ===
    labels = {'Initial Belief', 'Final Belief'};
    B = 1e5;  % Number of bootstrap replications
    p_values = zeros(1, 2);  % Store p-values

    % === Bootstrap test: Control vs Treatment ===
    % H0: μ_Control ≤ μ_Treatment (one-sided)
    for i = 1:2
        if i == 1
            x_ctrl = control_first;
            x_treat = treat_first;
        else
            x_ctrl = control_last;
            x_treat = treat_last;
        end

        obs_diff = mean(x_ctrl) - mean(x_treat);  % Observed mean difference

        % Bootstrap distribution of differences
        boot_diffs = zeros(B, 1);
        for b = 1:B
            sample_ctrl = x_ctrl(randi(n_c, n_c, 1));
            sample_treat = x_treat(randi(n_t, n_t, 1));
            boot_diffs(b) = mean(sample_ctrl) - mean(sample_treat);
        end

        % One-sided p-value (Control ≤ Treatment)
        p_values(i) = mean(boot_diffs <= 0);
    end

    % === Print results to console ===
    fprintf('--- Bootstrap One-Sided Test: H0: Control ≤ Narrative ---\n');
    fprintf('Initial Belief: p = %.4f\n', p_values(1));
    fprintf('Final Belief  : p = %.4f\n', p_values(2));

    % === Boxchart Plot ===
    figure('Name', 'Initial and Final Beliefs by Treatment', 'Color', 'w');
    hold on;

    % Round 1 (Initial)
    boxchart(ones(n_c,1)*0.85, control_first, ...
        'BoxFaceColor', [0.2 0.6 0.8], 'BoxWidth', 0.25);  % Control
    boxchart(ones(n_t,1)*1.15, treat_first, ...
        'BoxFaceColor', [0.9 0.4 0.4], 'BoxWidth', 0.25);  % Narrative

    % Round 11 (Final)
    boxchart(ones(n_c,1)*1.85, control_last, ...
        'BoxFaceColor', [0.2 0.6 0.8], 'BoxWidth', 0.25);  % Control
    boxchart(ones(n_t,1)*2.15, treat_last, ...
        'BoxFaceColor', [0.9 0.4 0.4], 'BoxWidth', 0.25);  % Narrative

    % === Plot Aesthetics ===
    xlim([0.5 2.5]);
    xticks([1 2]);
    xticklabels(labels);
    ylabel('Belief');
    title('Initial and Final Beliefs by Group');
    legend('Control', 'Narratives', 'Location', 'southoutside', ...
        'Orientation', 'horizontal');
    grid on;
    hold off;

end
