function bootstrap_behavioral_model(data_matrix, B, label)
% =========================================================================
% BOOTSTRAP_BEHAVIORAL_MODEL
%
% Perform bootstrap estimation of the behavioral model via EM algorithm.
% Stores off-diagonal elements of the misperception matrix Pi and sigma^2.
% Each iteration re-estimates parameters using a resampled version of the data.
%
% INPUT:
%   data_matrix : [N x 21] matrix with beliefs and signals
%   B           : number of bootstrap iterations
%   label       : string used for saving output (e.g., 'control' or 'treatment')
%
% OUTPUT:
%   Saves `bootstrap_results_<label>.mat` with:
%       - param_values : [B x 7] bootstrap estimates
%       - param_names  : names of 6 Pi off-diagonal elements
%       - sigma_name   : label for sigma^2
%
% Requires: estimate_behavioral_model.m (with manual normpdf)
% =========================================================================

    if nargin < 3
        error("Please provide a label, e.g., 'control' or 'treatment'");
    end

    % === Fix seed for reproducibility ===
    rng(1234);

    [N, ~] = size(data_matrix);

    % Parameter labels (for histogram plotting later)
    param_names = {
        '\Pi_{1,2}', '\Pi_{1,3}';
        '\Pi_{2,1}', '\Pi_{2,3}';
        '\Pi_{3,1}', '\Pi_{3,2}'
    };
    sigma_name = '\sigma^2';

    % Initialize matrix for bootstrap results
    param_values = NaN(B, 7);  % 6 Pi off-diagonal + 1 sigma^2
    success_count = 0;

    for b = 1:B
        % === Step 1: Resample with replacement ===
        sample_idx = ceil(N * rand(N, 1));
        boot_sample = data_matrix(sample_idx, :);

        try
            % === Step 2: Estimate behavioral model on bootstrap sample ===
            [Pi_hat, sigma2_hat] = estimate_behavioral_model(boot_sample, 200, 1e-6);

            % === Step 3: Store relevant parameters ===
            param_values(b, :) = [
                Pi_hat(1,2), Pi_hat(1,3), ...
                Pi_hat(2,1), Pi_hat(2,3), ...
                Pi_hat(3,1), Pi_hat(3,2), ...
                sigma2_hat
            ];

            success_count = success_count + 1;

        catch ME
            warning("Bootstrap sample %d failed: %s", b, ME.message);
        end

        % Optional progress update
        if mod(b, 10) == 0
            fprintf('Completed %d / %d iterations...\n', b, B);
        end
    end

    % === Step 4: Save results ===
    save(sprintf('bootstrap_results_%s.mat', label), ...
        'param_values', 'param_names', 'sigma_name');

    fprintf('Bootstrap completed: %d out of %d iterations successful.\n', success_count, B);
end
