% =========================================================================
% ANALYZE_BOOTSTRAP_RESULTS
%
% This script compares bootstrap-estimated parameters for Control vs. Treatment.
% It visualizes the posterior distributions, computes summary statistics,
% and reports p-values for selected comparisons.
%
% Requires:
%   - bootstrap_results_control.mat
%   - bootstrap_results_treatment.mat
% =========================================================================

% === Load parameter matrices ===
load('bootstrap_results_control.mat', 'param_values');
control_vals = param_values;

load('bootstrap_results_treatment.mat', 'param_values');
treatment_vals = param_values;

% === Plot histograms for each group ===
for group = ["control", "treatment"]
    load(sprintf('bootstrap_results_%s.mat', group), 'param_values', 'param_names', 'sigma_name');

    figure('Name', sprintf('Bootstrap Estimates (%s)', group), 'Position', [100 100 1200 800]);
    k = 1;
    for row = 1:3
        for col = 1:2
            subplot(3, 3, (row-1)*3 + col);
            histogram(param_values(:,k), 30, 'FaceColor', [0.3 0.5 0.8], 'EdgeColor', 'k');
            title(param_names{row, col}, 'Interpreter', 'tex');
            xlabel('Value'); ylabel('Frequency');
            k = k + 1;
        end
    end

    % Sigma^2
    subplot(3,3,3);
    histogram(param_values(:,7), 30, 'FaceColor', [0.7 0.4 0.4], 'EdgeColor', 'k');
    title(sigma_name, 'Interpreter', 'tex');
    xlabel('Value'); ylabel('Frequency');

    % Pi_{2,1} - Pi_{2,3}
    delta = param_values(:,3) - param_values(:,4);
    subplot(3,3,9);
    histogram(delta, 30, 'FaceColor', [0.5 0.8 0.5], 'EdgeColor', 'k');
    title('\Delta = \Pi_{2,1} - \Pi_{2,3}', 'Interpreter', 'tex');
    xlabel('Value'); ylabel('Frequency');

    sgtitle(sprintf('Bootstrap Estimates (%s)', group), 'FontWeight', 'bold');
    saveas(gcf, sprintf('bootstrap_histograms_%s.png', group));

    % Summary for delta
    q = prctile(delta, [5 50 95]);
    fprintf('\n--- Δ = Pi_{2,1} - Pi_{2,3} in %s ---\n', upper(group));
    fprintf('%15s %8.4f %8.4f %8.4f %8.4f %8.4f\n', ...
        '\Delta', min(delta), q(1), q(2), q(3), max(delta));
    fprintf('Percentile where Δ < 0: %.2f%%\n', mean(delta < 0) * 100);
end

% === Summary statistics ===
full_labels = {
    'Pi_C_12', 'Pi_C_13', 'Pi_C_21', 'Pi_C_23', 'Pi_C_31', 'Pi_C_32', 'Sigma_C';
    'Pi_T_12', 'Pi_T_13', 'Pi_T_21', 'Pi_T_23', 'Pi_T_31', 'Pi_T_32', 'Sigma_T'
};

fprintf('\n--- Bootstrap Summary Statistics ---\n');
fprintf('%15s %8s %8s %8s %8s %8s\n', 'Parameter', 'Min', 'P5', 'Median', 'P95', 'Max');

for i = 1:7
    % Control
    vec = control_vals(:,i);
    q = prctile(vec, [5 50 95]);
    fprintf('%15s %8.4f %8.4f %8.4f %8.4f %8.4f\n', full_labels{1,i}, ...
        min(vec), q(1), q(2), q(3), max(vec));

    % Treatment
    vec = treatment_vals(:,i);
    q = prctile(vec, [5 50 95]);
    fprintf('%15s %8.4f %8.4f %8.4f %8.4f %8.4f\n', full_labels{2,i}, ...
        min(vec), q(1), q(2), q(3), max(vec));
end

% === Compare key parameters using two-sided bootstrap p-values ===
fprintf('\n--- Selected Two-Sided Bootstrap p-values (Mean Differences) ---\n');
B_resample = 10000;

% Resample p-value function
bootstrap_mean_diff_pval = @(x, y, B) ...
    2 * min( ...
        mean(arrayfun(@(~) mean(x(randi(length(x), length(x), 1))) - ...
                            mean(y(randi(length(y), length(y), 1))), 1:B) < 0), ...
        mean(arrayfun(@(~) mean(x(randi(length(x), length(x), 1))) - ...
                            mean(y(randi(length(y), length(y), 1))), 1:B) > 0) ...
    );

% Extract parameter vectors
pi_c_21 = control_vals(:, 3);  pi_t_21 = treatment_vals(:, 3);
pi_c_23 = control_vals(:, 4);  pi_t_23 = treatment_vals(:, 4);
sigma_c = control_vals(:, 7);  sigma_t = treatment_vals(:, 7);

% Compute and print p-values
fprintf('P(Pi_{2,1}^{Control} ≠ Pi_{2,1}^{Narrative}) = %.4f\n', ...
    bootstrap_mean_diff_pval(pi_c_21, pi_t_21, B_resample));
fprintf('P(Pi_{2,3}^{Control} ≠ Pi_{2,3}^{Narrative}) = %.4f\n', ...
    bootstrap_mean_diff_pval(pi_c_23, pi_t_23, B_resample));
fprintf('P(Pi_{2,1}^{Control} ≠ Pi_{2,3}^{Narrative}) = %.4f\n', ...
    bootstrap_mean_diff_pval(pi_c_21, pi_t_23, B_resample));
fprintf('P(Pi_{2,3}^{Control} ≠ Pi_{2,1}^{Narrative}) = %.4f\n', ...
    bootstrap_mean_diff_pval(pi_c_23, pi_t_21, B_resample));
fprintf('P(sigma^2_{Control} ≠ sigma^2_{Narrative}) = %.4f\n', ...
    bootstrap_mean_diff_pval(sigma_c, sigma_t, B_resample));
