function [Pi_hat, sigma2_hat, gamma] = estimate_behavioral_model(data_matrix, max_iter, tol)
% =========================================================================
% ESTIMATE_BEHAVIORAL_MODEL
%
% EM algorithm to estimate:
%   - misperception matrix Pi (3x3),
%   - noise variance sigma^2,
% from belief updating behavior under uncertain signals.
%
% INPUT:
%   data_matrix : [N x 21] or [N x 11] matrix
%                 - beliefs (p0 to pT) in the first T+1 columns
%                 - signals (s1 to sT) in the remaining T columns
%   max_iter    : max number of EM iterations (default: 200)
%   tol         : convergence threshold (default: 1e-6)
%
% OUTPUT:
%   Pi_hat      : [3 x 3] estimated misperception matrix
%   sigma2_hat  : estimated variance of belief noise
%   gamma       : [N x T x 3] posterior weights over perceived signals
% =========================================================================

    % === Handle optional arguments ===
    if nargin < 2, max_iter = 200; end
    if nargin < 3, tol = 1e-6; end

    [N, total_cols] = size(data_matrix);  % Number of subjects

    % === Determine time horizon T ===
    if total_cols == 21
        T = 10;  % Full data: 11 beliefs, 10 signals
        beliefs = data_matrix(:, 1:11);
        signals = data_matrix(:, 12:21);
    elseif total_cols == 11
        T = 5;   % Half data: 6 beliefs, 5 signals
        beliefs = data_matrix(:, 1:6);
        signals = data_matrix(:, 7:11);
    else
        error('Invalid input: data_matrix must have 21 or 11 columns.');
    end

    % === Initialization ===
    Pi_hat = (1 - 3 * 0.05) * eye(3) + 0.05 * ones(3);  % Start close to identity
    sigma2_hat = 0.001;  % Small initial noise
    gamma = zeros(N, T, 3);  % Posterior belief over perceived signals

    signal_map = containers.Map([-1, 0, 1], [1, 2, 3]);  % Map signal → index

    % Signal distributions conditional on B and A
    P_B = [0.30, 0.25, 0.45];  % P(signal = -1, 0, +1 | B)
    P_A = [0.45, 0.25, 0.30];  % P(signal = -1, 0, +1 | A)

    % === EM algorithm ===
    for iter = 1:max_iter
        Pi_old = Pi_hat;
        sigma2_old = sigma2_hat;

        % --- E-step ---
        for i = 1:N
            for t = 1:T
                p_prior = beliefs(i, t);       % p_{t-1}
                y_obs = beliefs(i, t + 1);     % p_t
                s_true = signals(i, t);        % true signal
                s_idx = signal_map(s_true);    % index: 1 (-1), 2 (0), 3 (+1)

                % Compute Bayesian posterior for each perceived signal j
                r = zeros(1, 3);
                for j = 1:3
                    num = p_prior * P_B(j);
                    den = num + (1 - p_prior) * P_A(j);
                    r(j) = num / den;
                end

                % Compute likelihood for each perceived signal
                diff = y_obs - r;
                numerators = Pi_hat(s_idx, :) .* (1 / sqrt(2 * pi * sigma2_hat)) .* exp(- (diff.^2) / (2 * sigma2_hat));
                gamma(i, t, :) = numerators / sum(numerators);  % Normalize
            end
        end

        % --- M-step: update Pi ---
        Pi_new = zeros(3, 3);
        counts = zeros(3, 1);
        for i = 1:N
            for t = 1:T
                s_idx = signal_map(signals(i, t));
                Pi_new(s_idx, :) = Pi_new(s_idx, :) + squeeze(gamma(i, t, :))';
                counts(s_idx) = counts(s_idx) + 1;
            end
        end
        for s = 1:3
            if counts(s) > 0
                Pi_hat(s, :) = Pi_new(s, :) / counts(s);  % Row normalization
            end
        end

        % --- M-step: update sigma^2 ---
        sq_error = 0;
        for i = 1:N
            for t = 1:T
                p_prior = beliefs(i, t);
                y_obs = beliefs(i, t+1);

                % Recompute Bayesian posteriors
                r = zeros(1, 3);
                for j = 1:3
                    num = p_prior * P_B(j);
                    den = num + (1 - p_prior) * P_A(j);
                    r(j) = num / den;
                end

                for j = 1:3
                    sq_error = sq_error + gamma(i, t, j) * (y_obs - r(j))^2;
                end
            end
        end
        sigma2_hat = sq_error / (N * T);

        % --- Convergence check ---
        if max(abs(Pi_hat(:) - Pi_old(:))) < tol && abs(sigma2_hat - sigma2_old) < tol
            fprintf('Converged at iteration %d\n', iter);
            break;
        end
    end

    % === Display final estimates ===
    disp('Estimated misperception matrix (Pi):');
    disp(Pi_hat);
    disp('Estimated noise variance (sigma^2):');
    disp(sigma2_hat);
end
