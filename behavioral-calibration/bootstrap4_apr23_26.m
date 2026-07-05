%% ============================================================
%  BOOTSTRAP FOR 4-TYPE SUBJECT-LEVEL CLASSIFICATION (BIC)
%
%  Types:
%   1. Reaction-intensity
%   2. Reaction-intensity with neutral reset
%   3. Extreme reset
%   4. Extreme inertia
%
%  Classification criterion:
%   - smallest BIC
%
%  Type 1: Reaction-intensity
%    if sign = +1:
%      b_{t+1} = [b_t * (3/2)^lambda] / [b_t * (3/2)^lambda + (1-b_t)]
%    if sign =  0:
%      b_{t+1} = b_t
%    if sign = -1:
%      b_{t+1} = [b_t * (2/3)^lambda] / [b_t * (2/3)^lambda + (1-b_t)]
%
%  Type 2: Reaction-intensity with neutral reset
%    same as above for informative signals, but:
%    if sign = 0:
%      b_{t+1} = 0.5
%
%  Type 3: Extreme reset
%    if sign = +1: 1
%    if sign =  0: 0.5
%    if sign = -1: 0
%
%  Type 4: Extreme inertia
%    if sign = +1: 1
%    if sign =  0: b_t
%    if sign = -1: 0
%
%  Bootstrap:
%   - resample subjects with replacement within treatment
%   - keep all observations of each selected subject
%   - classify each sampled subject by smallest BIC
%
%  Output:
%   - treatment-level shares
%   - mean sigmas by type/treatment
%   - mean lambda for the two reaction-intensity types
%   - across-treatment differences
%   - within-treatment differences
%% ============================================================

clear; clc;
rng(12345);

%% 0. User choices
skipFirstRounds = 0;   % exclude rounds 1,...,skipFirstRounds
skipLastRounds  = 0;   % exclude last rounds
B = 10000;              % bootstrap replications

remainingRounds = 10 - skipFirstRounds - skipLastRounds;
if remainingRounds <= 0
    error('You excluded too many rounds: no updating rounds remain.');
end

%% 1. Import data
fname = 'data_narrative_with_followup.xls';
T = readtable(fname);

%% 2. Basic cleaning
lastKeptRound = 10 - skipLastRounds;

keep = (T.round >= 1) ...
    & (T.round > skipFirstRounds) ...
    & (T.round <= lastKeptRound) ...
    & ~isnan(T.belief) ...
    & ~isnan(T.b_lag) ...
    & ~isnan(T.bayes_post) ...
    & ~isnan(T.sign);

D = T(keep, :);

D.id         = string(D.id);
D.sign       = double(D.sign);
D.belief     = double(D.belief);
D.b_lag      = double(D.b_lag);
D.bayes_post = double(D.bayes_post);

D = D(ismember(D.sign, [-1 0 1]), :);

fprintf('Skipping first %d updating rounds.\n', skipFirstRounds);
fprintf('Skipping last %d updating rounds.\n', skipLastRounds);
fprintf('Remaining updating rounds per subject, if complete: %d\n', remainingRounds);

%% 3. Split by treatment
isControl   = strcmpi(string(D.treatment), "Control");
isNarrative = strcmpi(string(D.treatment), "Narratives") | strcmpi(string(D.treatment), "Narrative");
isFollowup  = strcmpi(string(D.treatment), "Followup")   | strcmpi(string(D.treatment), "No Info");

Groups = struct();
Groups.Control   = D(isControl, :);
Groups.Narrative = D(isNarrative, :);
Groups.Followup  = D(isFollowup, :);

groupNames = {'Control','Narrative','Followup'};

fprintf('Observations by treatment:\n');
fprintf('  Control   N = %d\n', height(Groups.Control));
fprintf('  Narrative N = %d\n', height(Groups.Narrative));
fprintf('  Followup  N = %d\n', height(Groups.Followup));

%% 4. Options
opts = struct();
opts.minObs      = max(2, remainingRounds);
opts.sigmaLB     = 1e-4;
opts.sigmaUB     = 0.5;
opts.lambdaLB    = 0.01;
opts.lambdaUB    = 20;
opts.epsFloor    = 1e-300;
opts.verbose     = false;

%% 5. Bootstrap storage

% Shares by treatment
shareRI  = nan(B,3);
shareRIR = nan(B,3);
shareER  = nan(B,3);
shareEI  = nan(B,3);

% Mean sigma by treatment and type
meanSigma_RI  = nan(B,3);
meanSigma_RIR = nan(B,3);
meanSigma_ER  = nan(B,3);
meanSigma_EI  = nan(B,3);

% Mean lambda by treatment and type
meanLambda_RI  = nan(B,3);
meanLambda_RIR = nan(B,3);

% Counts
nRI  = nan(B,3);
nRIR = nan(B,3);
nER  = nan(B,3);
nEI  = nan(B,3);

%% 6. Bootstrap loop
for b = 1:B
    if mod(b,50)==0 || b==1
        fprintf('Bootstrap replication %d / %d\n', b, B);
    end

    for g = 1:3
        gname = groupNames{g};
        G = Groups.(gname);

        ids = unique(G.id);
        nSubj = numel(ids);

        % Resample subjects with replacement
        draw_idx = randi(nSubj, nSubj, 1);
        sampled_ids = ids(draw_idx);

        % Reclassify sampled subjects
        best_model = strings(nSubj,1);
        sigma_hat  = nan(nSubj,1);
        lambda_hat = nan(nSubj,1);

        for j = 1:nSubj
            thisID = sampled_ids(j);
            Sj = G(G.id == thisID, :);

            y  = Sj.belief(:);
            s  = Sj.sign(:);
            bl = Sj.b_lag(:);

            if numel(y) < opts.minObs
                best_model(j) = "Missing";
                continue
            end

            fit1 = fit_type1_reaction_intensity(y, s, bl, opts);
            fit2 = fit_type2_reaction_intensity_reset(y, s, bl, opts);
            fit3 = fit_type3_extreme_reset(y, s, opts);
            fit4 = fit_type4_extreme_inertia(y, s, bl, opts);

            bicVals = [fit1.BIC, fit2.BIC, fit3.BIC, fit4.BIC];
            typeNames = ["ReactionIntensity","ReactionIntensityReset","ExtremeReset","ExtremeInertia"];

            [~, ix] = min(bicVals);
            best_model(j) = typeNames(ix);

            if best_model(j) == "ReactionIntensity"
                sigma_hat(j)  = fit1.sigma;
                lambda_hat(j) = fit1.lambda;
            elseif best_model(j) == "ReactionIntensityReset"
                sigma_hat(j)  = fit2.sigma;
                lambda_hat(j) = fit2.lambda;
            elseif best_model(j) == "ExtremeReset"
                sigma_hat(j) = fit3.sigma;
            elseif best_model(j) == "ExtremeInertia"
                sigma_hat(j) = fit4.sigma;
            end
        end

        % Shares
        shareRI(b,g)  = mean(best_model == "ReactionIntensity");
        shareRIR(b,g) = mean(best_model == "ReactionIntensityReset");
        shareER(b,g)  = mean(best_model == "ExtremeReset");
        shareEI(b,g)  = mean(best_model == "ExtremeInertia");

        % Counts
        idxRI  = (best_model == "ReactionIntensity");
        idxRIR = (best_model == "ReactionIntensityReset");
        idxER  = (best_model == "ExtremeReset");
        idxEI  = (best_model == "ExtremeInertia");

        nRI(b,g)  = sum(idxRI);
        nRIR(b,g) = sum(idxRIR);
        nER(b,g)  = sum(idxER);
        nEI(b,g)  = sum(idxEI);

        % Means
        if any(idxRI)
            meanSigma_RI(b,g)  = mean(sigma_hat(idxRI), 'omitnan');
            meanLambda_RI(b,g) = mean(lambda_hat(idxRI), 'omitnan');
        end
        if any(idxRIR)
            meanSigma_RIR(b,g)  = mean(sigma_hat(idxRIR), 'omitnan');
            meanLambda_RIR(b,g) = mean(lambda_hat(idxRIR), 'omitnan');
        end
        if any(idxER)
            meanSigma_ER(b,g) = mean(sigma_hat(idxER), 'omitnan');
        end
        if any(idxEI)
            meanSigma_EI(b,g) = mean(sigma_hat(idxEI), 'omitnan');
        end
    end
end

%% 7. Across-treatment differences in shares

% Reaction-intensity
diff_shareRI_NC  = shareRI(:,2)  - shareRI(:,1);
diff_shareRI_FC  = shareRI(:,3)  - shareRI(:,1);
diff_shareRI_NF  = shareRI(:,2)  - shareRI(:,3);

% Reaction-intensity + reset
diff_shareRIR_NC = shareRIR(:,2) - shareRIR(:,1);
diff_shareRIR_FC = shareRIR(:,3) - shareRIR(:,1);
diff_shareRIR_NF = shareRIR(:,2) - shareRIR(:,3);

% Extreme reset
diff_shareER_NC  = shareER(:,2)  - shareER(:,1);
diff_shareER_FC  = shareER(:,3)  - shareER(:,1);
diff_shareER_NF  = shareER(:,2)  - shareER(:,3);

% Extreme inertia
diff_shareEI_NC  = shareEI(:,2)  - shareEI(:,1);
diff_shareEI_FC  = shareEI(:,3)  - shareEI(:,1);
diff_shareEI_NF  = shareEI(:,2)  - shareEI(:,3);

%% 8. Within-treatment differences in shares

% Control
within_C_RI_RIR = shareRI(:,1)  - shareRIR(:,1);
within_C_RI_ER  = shareRI(:,1)  - shareER(:,1);
within_C_RI_EI  = shareRI(:,1)  - shareEI(:,1);
within_C_RIR_ER = shareRIR(:,1) - shareER(:,1);
within_C_RIR_EI = shareRIR(:,1) - shareEI(:,1);
within_C_ER_EI  = shareER(:,1)  - shareEI(:,1);

% Narrative
within_N_RI_RIR = shareRI(:,2)  - shareRIR(:,2);
within_N_RI_ER  = shareRI(:,2)  - shareER(:,2);
within_N_RI_EI  = shareRI(:,2)  - shareEI(:,2);
within_N_RIR_ER = shareRIR(:,2) - shareER(:,2);
within_N_RIR_EI = shareRIR(:,2) - shareEI(:,2);
within_N_ER_EI  = shareER(:,2)  - shareEI(:,2);

% Followup
within_F_RI_RIR = shareRI(:,3)  - shareRIR(:,3);
within_F_RI_ER  = shareRI(:,3)  - shareER(:,3);
within_F_RI_EI  = shareRI(:,3)  - shareEI(:,3);
within_F_RIR_ER = shareRIR(:,3) - shareER(:,3);
within_F_RIR_EI = shareRIR(:,3) - shareEI(:,3);
within_F_ER_EI  = shareER(:,3)  - shareEI(:,3);

%% 9. Across-treatment differences in mean sigmas

% RI
diff_sigmaRI_NC  = meanSigma_RI(:,2)  - meanSigma_RI(:,1);
diff_sigmaRI_FC  = meanSigma_RI(:,3)  - meanSigma_RI(:,1);
diff_sigmaRI_NF  = meanSigma_RI(:,2)  - meanSigma_RI(:,3);

% RIR
diff_sigmaRIR_NC = meanSigma_RIR(:,2) - meanSigma_RIR(:,1);
diff_sigmaRIR_FC = meanSigma_RIR(:,3) - meanSigma_RIR(:,1);
diff_sigmaRIR_NF = meanSigma_RIR(:,2) - meanSigma_RIR(:,3);

% ER
diff_sigmaER_NC  = meanSigma_ER(:,2)  - meanSigma_ER(:,1);
diff_sigmaER_FC  = meanSigma_ER(:,3)  - meanSigma_ER(:,1);
diff_sigmaER_NF  = meanSigma_ER(:,2)  - meanSigma_ER(:,3);

% EI
diff_sigmaEI_NC  = meanSigma_EI(:,2)  - meanSigma_EI(:,1);
diff_sigmaEI_FC  = meanSigma_EI(:,3)  - meanSigma_EI(:,1);
diff_sigmaEI_NF  = meanSigma_EI(:,2)  - meanSigma_EI(:,3);

%% 10. Across-treatment differences in mean lambdas

% RI
diff_lambdaRI_NC  = meanLambda_RI(:,2)  - meanLambda_RI(:,1);
diff_lambdaRI_FC  = meanLambda_RI(:,3)  - meanLambda_RI(:,1);
diff_lambdaRI_NF  = meanLambda_RI(:,2)  - meanLambda_RI(:,3);

% RIR
diff_lambdaRIR_NC = meanLambda_RIR(:,2) - meanLambda_RIR(:,1);
diff_lambdaRIR_FC = meanLambda_RIR(:,3) - meanLambda_RIR(:,1);
diff_lambdaRIR_NF = meanLambda_RIR(:,2) - meanLambda_RIR(:,3);

%% 11. Within-treatment differences in sigmas

% Control
within_sigma_C_RI_RIR = meanSigma_RI(:,1)  - meanSigma_RIR(:,1);
within_sigma_C_RI_ER  = meanSigma_RI(:,1)  - meanSigma_ER(:,1);
within_sigma_C_RI_EI  = meanSigma_RI(:,1)  - meanSigma_EI(:,1);
within_sigma_C_RIR_ER = meanSigma_RIR(:,1) - meanSigma_ER(:,1);
within_sigma_C_RIR_EI = meanSigma_RIR(:,1) - meanSigma_EI(:,1);
within_sigma_C_ER_EI  = meanSigma_ER(:,1)  - meanSigma_EI(:,1);

% Narrative
within_sigma_N_RI_RIR = meanSigma_RI(:,2)  - meanSigma_RIR(:,2);
within_sigma_N_RI_ER  = meanSigma_RI(:,2)  - meanSigma_ER(:,2);
within_sigma_N_RI_EI  = meanSigma_RI(:,2)  - meanSigma_EI(:,2);
within_sigma_N_RIR_ER = meanSigma_RIR(:,2) - meanSigma_ER(:,2);
within_sigma_N_RIR_EI = meanSigma_RIR(:,2) - meanSigma_EI(:,2);
within_sigma_N_ER_EI  = meanSigma_ER(:,2)  - meanSigma_EI(:,2);

% Followup
within_sigma_F_RI_RIR = meanSigma_RI(:,3)  - meanSigma_RIR(:,3);
within_sigma_F_RI_ER  = meanSigma_RI(:,3)  - meanSigma_ER(:,3);
within_sigma_F_RI_EI  = meanSigma_RI(:,3)  - meanSigma_EI(:,3);
within_sigma_F_RIR_ER = meanSigma_RIR(:,3) - meanSigma_ER(:,3);
within_sigma_F_RIR_EI = meanSigma_RIR(:,3) - meanSigma_EI(:,3);
within_sigma_F_ER_EI  = meanSigma_ER(:,3)  - meanSigma_EI(:,3);

%% 12. Within-treatment differences in lambdas

within_lambda_C_RI_RIR = meanLambda_RI(:,1) - meanLambda_RIR(:,1);
within_lambda_N_RI_RIR = meanLambda_RI(:,2) - meanLambda_RIR(:,2);
within_lambda_F_RI_RIR = meanLambda_RI(:,3) - meanLambda_RIR(:,3);

%% 13. Save
save('bootstrap_results_subject_types_four_models_BIC.mat', ...
    'shareRI','shareRIR','shareER','shareEI', ...
    'meanSigma_RI','meanSigma_RIR','meanSigma_ER','meanSigma_EI', ...
    'meanLambda_RI','meanLambda_RIR', ...
    'nRI','nRIR','nER','nEI', ...
    'diff_shareRI_NC','diff_shareRI_FC','diff_shareRI_NF', ...
    'diff_shareRIR_NC','diff_shareRIR_FC','diff_shareRIR_NF', ...
    'diff_shareER_NC','diff_shareER_FC','diff_shareER_NF', ...
    'diff_shareEI_NC','diff_shareEI_FC','diff_shareEI_NF', ...
    'within_C_RI_RIR','within_C_RI_ER','within_C_RI_EI','within_C_RIR_ER','within_C_RIR_EI','within_C_ER_EI', ...
    'within_N_RI_RIR','within_N_RI_ER','within_N_RI_EI','within_N_RIR_ER','within_N_RIR_EI','within_N_ER_EI', ...
    'within_F_RI_RIR','within_F_RI_ER','within_F_RI_EI','within_F_RIR_ER','within_F_RIR_EI','within_F_ER_EI', ...
    'diff_sigmaRI_NC','diff_sigmaRI_FC','diff_sigmaRI_NF', ...
    'diff_sigmaRIR_NC','diff_sigmaRIR_FC','diff_sigmaRIR_NF', ...
    'diff_sigmaER_NC','diff_sigmaER_FC','diff_sigmaER_NF', ...
    'diff_sigmaEI_NC','diff_sigmaEI_FC','diff_sigmaEI_NF', ...
    'diff_lambdaRI_NC','diff_lambdaRI_FC','diff_lambdaRI_NF', ...
    'diff_lambdaRIR_NC','diff_lambdaRIR_FC','diff_lambdaRIR_NF', ...
    'within_sigma_C_RI_RIR','within_sigma_C_RI_ER','within_sigma_C_RI_EI','within_sigma_C_RIR_ER','within_sigma_C_RIR_EI','within_sigma_C_ER_EI', ...
    'within_sigma_N_RI_RIR','within_sigma_N_RI_ER','within_sigma_N_RI_EI','within_sigma_N_RIR_ER','within_sigma_N_RIR_EI','within_sigma_N_ER_EI', ...
    'within_sigma_F_RI_RIR','within_sigma_F_RI_ER','within_sigma_F_RI_EI','within_sigma_F_RIR_ER','within_sigma_F_RIR_EI','within_sigma_F_ER_EI', ...
    'within_lambda_C_RI_RIR','within_lambda_N_RI_RIR','within_lambda_F_RI_RIR', ...
    'skipFirstRounds','skipLastRounds','remainingRounds');

fprintf('\nSaved bootstrap_results_subject_types_four_models_BIC.mat\n');

%% 14. Print summaries
fprintf('\n============= BOOTSTRAP SUMMARIES (BIC classification: Reaction-intensity / Reaction-intensity + reset / Extreme reset / Extreme inertia) =============\n');

fprintf('\n--- Treatment-level shares ---\n');
print_bootstrap_summary('Reaction-intensity share - Control',   shareRI(:,1));
print_bootstrap_summary('Reaction-intensity share - Narrative', shareRI(:,2));
print_bootstrap_summary('Reaction-intensity share - Followup',  shareRI(:,3));

print_bootstrap_summary('Reaction-intensity + reset share - Control',   shareRIR(:,1));
print_bootstrap_summary('Reaction-intensity + reset share - Narrative', shareRIR(:,2));
print_bootstrap_summary('Reaction-intensity + reset share - Followup',  shareRIR(:,3));

print_bootstrap_summary('Extreme reset share - Control',   shareER(:,1));
print_bootstrap_summary('Extreme reset share - Narrative', shareER(:,2));
print_bootstrap_summary('Extreme reset share - Followup',  shareER(:,3));

print_bootstrap_summary('Extreme inertia share - Control',   shareEI(:,1));
print_bootstrap_summary('Extreme inertia share - Narrative', shareEI(:,2));
print_bootstrap_summary('Extreme inertia share - Followup',  shareEI(:,3));

fprintf('\n--- Across-treatment differences: shares ---\n');

fprintf('\nReaction-intensity:\n');
print_bootstrap_summary('Narrative - Control', diff_shareRI_NC);
print_bootstrap_summary('Followup - Control',  diff_shareRI_FC);
print_bootstrap_summary('Narrative - Followup',diff_shareRI_NF);

fprintf('\nReaction-intensity + reset:\n');
print_bootstrap_summary('Narrative - Control', diff_shareRIR_NC);
print_bootstrap_summary('Followup - Control',  diff_shareRIR_FC);
print_bootstrap_summary('Narrative - Followup',diff_shareRIR_NF);

fprintf('\nExtreme reset:\n');
print_bootstrap_summary('Narrative - Control', diff_shareER_NC);
print_bootstrap_summary('Followup - Control',  diff_shareER_FC);
print_bootstrap_summary('Narrative - Followup',diff_shareER_NF);

fprintf('\nExtreme inertia:\n');
print_bootstrap_summary('Narrative - Control', diff_shareEI_NC);
print_bootstrap_summary('Followup - Control',  diff_shareEI_FC);
print_bootstrap_summary('Narrative - Followup',diff_shareEI_NF);

fprintf('\n--- Within-treatment differences: shares ---\n');

fprintf('\nControl:\n');
print_bootstrap_summary('Reaction-intensity - Reaction-intensity + reset', within_C_RI_RIR);
print_bootstrap_summary('Reaction-intensity - Extreme reset', within_C_RI_ER);
print_bootstrap_summary('Reaction-intensity - Extreme inertia', within_C_RI_EI);
print_bootstrap_summary('Reaction-intensity + reset - Extreme reset', within_C_RIR_ER);
print_bootstrap_summary('Reaction-intensity + reset - Extreme inertia', within_C_RIR_EI);
print_bootstrap_summary('Extreme reset - Extreme inertia', within_C_ER_EI);

fprintf('\nNarrative:\n');
print_bootstrap_summary('Reaction-intensity - Reaction-intensity + reset', within_N_RI_RIR);
print_bootstrap_summary('Reaction-intensity - Extreme reset', within_N_RI_ER);
print_bootstrap_summary('Reaction-intensity - Extreme inertia', within_N_RI_EI);
print_bootstrap_summary('Reaction-intensity + reset - Extreme reset', within_N_RIR_ER);
print_bootstrap_summary('Reaction-intensity + reset - Extreme inertia', within_N_RIR_EI);
print_bootstrap_summary('Extreme reset - Extreme inertia', within_N_ER_EI);

fprintf('\nFollowup:\n');
print_bootstrap_summary('Reaction-intensity - Reaction-intensity + reset', within_F_RI_RIR);
print_bootstrap_summary('Reaction-intensity - Extreme reset', within_F_RI_ER);
print_bootstrap_summary('Reaction-intensity - Extreme inertia', within_F_RI_EI);
print_bootstrap_summary('Reaction-intensity + reset - Extreme reset', within_F_RIR_ER);
print_bootstrap_summary('Reaction-intensity + reset - Extreme inertia', within_F_RIR_EI);
print_bootstrap_summary('Extreme reset - Extreme inertia', within_F_ER_EI);

fprintf('\n--- Mean sigma by type and treatment ---\n');
print_bootstrap_summary('Reaction-intensity sigma - Control',   meanSigma_RI(:,1));
print_bootstrap_summary('Reaction-intensity sigma - Narrative', meanSigma_RI(:,2));
print_bootstrap_summary('Reaction-intensity sigma - Followup',  meanSigma_RI(:,3));

print_bootstrap_summary('Reaction-intensity + reset sigma - Control',   meanSigma_RIR(:,1));
print_bootstrap_summary('Reaction-intensity + reset sigma - Narrative', meanSigma_RIR(:,2));
print_bootstrap_summary('Reaction-intensity + reset sigma - Followup',  meanSigma_RIR(:,3));

print_bootstrap_summary('Extreme reset sigma - Control',   meanSigma_ER(:,1));
print_bootstrap_summary('Extreme reset sigma - Narrative', meanSigma_ER(:,2));
print_bootstrap_summary('Extreme reset sigma - Followup',  meanSigma_ER(:,3));

print_bootstrap_summary('Extreme inertia sigma - Control',   meanSigma_EI(:,1));
print_bootstrap_summary('Extreme inertia sigma - Narrative', meanSigma_EI(:,2));
print_bootstrap_summary('Extreme inertia sigma - Followup',  meanSigma_EI(:,3));

fprintf('\n--- Across-treatment differences: mean sigmas ---\n');

fprintf('\nReaction-intensity sigma:\n');
print_bootstrap_summary('Narrative - Control', diff_sigmaRI_NC);
print_bootstrap_summary('Followup - Control',  diff_sigmaRI_FC);
print_bootstrap_summary('Narrative - Followup',diff_sigmaRI_NF);

fprintf('\nReaction-intensity + reset sigma:\n');
print_bootstrap_summary('Narrative - Control', diff_sigmaRIR_NC);
print_bootstrap_summary('Followup - Control',  diff_sigmaRIR_FC);
print_bootstrap_summary('Narrative - Followup',diff_sigmaRIR_NF);

fprintf('\nExtreme reset sigma:\n');
print_bootstrap_summary('Narrative - Control', diff_sigmaER_NC);
print_bootstrap_summary('Followup - Control',  diff_sigmaER_FC);
print_bootstrap_summary('Narrative - Followup',diff_sigmaER_NF);

fprintf('\nExtreme inertia sigma:\n');
print_bootstrap_summary('Narrative - Control', diff_sigmaEI_NC);
print_bootstrap_summary('Followup - Control',  diff_sigmaEI_FC);
print_bootstrap_summary('Narrative - Followup',diff_sigmaEI_NF);

fprintf('\n--- Mean lambda by type and treatment ---\n');
print_bootstrap_summary('Reaction-intensity lambda - Control',   meanLambda_RI(:,1));
print_bootstrap_summary('Reaction-intensity lambda - Narrative', meanLambda_RI(:,2));
print_bootstrap_summary('Reaction-intensity lambda - Followup',  meanLambda_RI(:,3));

print_bootstrap_summary('Reaction-intensity + reset lambda - Control',   meanLambda_RIR(:,1));
print_bootstrap_summary('Reaction-intensity + reset lambda - Narrative', meanLambda_RIR(:,2));
print_bootstrap_summary('Reaction-intensity + reset lambda - Followup',  meanLambda_RIR(:,3));

fprintf('\n--- Across-treatment differences: mean lambda ---\n');

fprintf('\nReaction-intensity lambda:\n');
print_bootstrap_summary('Narrative - Control', diff_lambdaRI_NC);
print_bootstrap_summary('Followup - Control',  diff_lambdaRI_FC);
print_bootstrap_summary('Narrative - Followup',diff_lambdaRI_NF);

fprintf('\nReaction-intensity + reset lambda:\n');
print_bootstrap_summary('Narrative - Control', diff_lambdaRIR_NC);
print_bootstrap_summary('Followup - Control',  diff_lambdaRIR_FC);
print_bootstrap_summary('Narrative - Followup',diff_lambdaRIR_NF);

fprintf('\n--- Within-treatment differences: mean sigmas ---\n');

fprintf('\nControl:\n');
print_bootstrap_summary('Reaction-intensity sigma - Reaction-intensity + reset sigma', within_sigma_C_RI_RIR);
print_bootstrap_summary('Reaction-intensity sigma - Extreme reset sigma', within_sigma_C_RI_ER);
print_bootstrap_summary('Reaction-intensity sigma - Extreme inertia sigma', within_sigma_C_RI_EI);
print_bootstrap_summary('Reaction-intensity + reset sigma - Extreme reset sigma', within_sigma_C_RIR_ER);
print_bootstrap_summary('Reaction-intensity + reset sigma - Extreme inertia sigma', within_sigma_C_RIR_EI);
print_bootstrap_summary('Extreme reset sigma - Extreme inertia sigma', within_sigma_C_ER_EI);

fprintf('\nNarrative:\n');
print_bootstrap_summary('Reaction-intensity sigma - Reaction-intensity + reset sigma', within_sigma_N_RI_RIR);
print_bootstrap_summary('Reaction-intensity sigma - Extreme reset sigma', within_sigma_N_RI_ER);
print_bootstrap_summary('Reaction-intensity sigma - Extreme inertia sigma', within_sigma_N_RI_EI);
print_bootstrap_summary('Reaction-intensity + reset sigma - Extreme reset sigma', within_sigma_N_RIR_ER);
print_bootstrap_summary('Reaction-intensity + reset sigma - Extreme inertia sigma', within_sigma_N_RIR_EI);
print_bootstrap_summary('Extreme reset sigma - Extreme inertia sigma', within_sigma_N_ER_EI);

fprintf('\nFollowup:\n');
print_bootstrap_summary('Reaction-intensity sigma - Reaction-intensity + reset sigma', within_sigma_F_RI_RIR);
print_bootstrap_summary('Reaction-intensity sigma - Extreme reset sigma', within_sigma_F_RI_ER);
print_bootstrap_summary('Reaction-intensity sigma - Extreme inertia sigma', within_sigma_F_RI_EI);
print_bootstrap_summary('Reaction-intensity + reset sigma - Extreme reset sigma', within_sigma_F_RIR_ER);
print_bootstrap_summary('Reaction-intensity + reset sigma - Extreme inertia sigma', within_sigma_F_RIR_EI);
print_bootstrap_summary('Extreme reset sigma - Extreme inertia sigma', within_sigma_F_ER_EI);

fprintf('\n--- Within-treatment differences: mean lambda ---\n');

fprintf('\nControl:\n');
print_bootstrap_summary('Reaction-intensity lambda - Reaction-intensity + reset lambda', within_lambda_C_RI_RIR);

fprintf('\nNarrative:\n');
print_bootstrap_summary('Reaction-intensity lambda - Reaction-intensity + reset lambda', within_lambda_N_RI_RIR);

fprintf('\nFollowup:\n');
print_bootstrap_summary('Reaction-intensity lambda - Reaction-intensity + reset lambda', within_lambda_F_RI_RIR);

%% ============================================================
%  LOCAL FUNCTIONS
%% ============================================================

function fit = fit_type1_reaction_intensity(y, s, b0, opts)
    obj = @(theta) nll_type1(exp(theta(1)), exp(theta(2)), y, s, b0, opts);
    theta0 = [log(0.10), log(1.0)];
    thetaHat = fminsearch(obj, theta0, ...
        optimset('Display','off','MaxFunEvals',5000,'MaxIter',5000));

    sigma  = exp(thetaHat(1));
    lambda = exp(thetaHat(2));

    loglik = -nll_type1(sigma, lambda, y, s, b0, opts);
    n = numel(y);
    k = 2;
    BIC = -2*loglik + k*log(n);

    fit.sigma  = sigma;
    fit.lambda = lambda;
    fit.loglik = loglik;
    fit.BIC    = BIC;
end

function fit = fit_type2_reaction_intensity_reset(y, s, b0, opts)
    obj = @(theta) nll_type2(exp(theta(1)), exp(theta(2)), y, s, b0, opts);
    theta0 = [log(0.10), log(1.0)];
    thetaHat = fminsearch(obj, theta0, ...
        optimset('Display','off','MaxFunEvals',5000,'MaxIter',5000));

    sigma  = exp(thetaHat(1));
    lambda = exp(thetaHat(2));

    loglik = -nll_type2(sigma, lambda, y, s, b0, opts);
    n = numel(y);
    k = 2;
    BIC = -2*loglik + k*log(n);

    fit.sigma  = sigma;
    fit.lambda = lambda;
    fit.loglik = loglik;
    fit.BIC    = BIC;
end

function fit = fit_type3_extreme_reset(y, s, opts)
    mu = 0.5 * ones(size(y));
    mu(s == +1) = 1.0;
    mu(s == -1) = 0.0;

    nllfun = @(sigma) nll_normal_model(sigma, y, mu, opts);
    sigma = estimate_sigma(nllfun, opts);
    loglik = -nllfun(sigma);
    n = numel(y);
    k = 1;
    BIC = -2*loglik + k*log(n);

    fit.sigma  = sigma;
    fit.loglik = loglik;
    fit.BIC    = BIC;
end

function fit = fit_type4_extreme_inertia(y, s, b0, opts)
    mu = b0;
    mu(s == +1) = 1.0;
    mu(s == -1) = 0.0;

    nllfun = @(sigma) nll_normal_model(sigma, y, mu, opts);
    sigma = estimate_sigma(nllfun, opts);
    loglik = -nllfun(sigma);
    n = numel(y);
    k = 1;
    BIC = -2*loglik + k*log(n);

    fit.sigma  = sigma;
    fit.loglik = loglik;
    fit.BIC    = BIC;
end

function val = nll_type1(sigma, lambda, y, s, b0, opts)
    mu = reaction_intensity_update(b0, s, lambda, false);
    dens = normal_pdf(y, mu, sigma);
    dens = max(dens, opts.epsFloor);
    val = -sum(log(dens));
end

function val = nll_type2(sigma, lambda, y, s, b0, opts)
    mu = reaction_intensity_update(b0, s, lambda, true);
    dens = normal_pdf(y, mu, sigma);
    dens = max(dens, opts.epsFloor);
    val = -sum(log(dens));
end

function mu = reaction_intensity_update(b0, s, lambda, resetNeutral)
    b0 = min(max(b0, 1e-10), 1 - 1e-10);
    mu = b0;

    idxP = (s == +1);
    idxN = (s == -1);
    idx0 = (s == 0);

    if any(idxP)
        a = (3/2)^lambda;
        mu(idxP) = (b0(idxP) .* a) ./ (b0(idxP) .* a + (1 - b0(idxP)));
    end

    if any(idxN)
        a = (2/3)^lambda;
        mu(idxN) = (b0(idxN) .* a) ./ (b0(idxN) .* a + (1 - b0(idxN)));
    end

    if any(idx0)
        if resetNeutral
            mu(idx0) = 0.5;
        else
            mu(idx0) = b0(idx0);
        end
    end

    mu = min(max(mu, 1e-10), 1 - 1e-10);
end

function val = nll_normal_model(sigma, y, mu, opts)
    dens = normal_pdf(y, mu, sigma);
    dens = max(dens, opts.epsFloor);
    val = -sum(log(dens));
end

function sigma = estimate_sigma(nllfun, opts)
    obj = @(lsig) nllfun(exp(lsig));
    lsig = fminbnd(obj, log(opts.sigmaLB), log(opts.sigmaUB));
    sigma = exp(lsig);
end

function f = normal_pdf(x, mu, sigma)
    sigma = max(sigma, 1e-12);
    z = (x - mu) ./ sigma;
    f = exp(-0.5 .* z.^2) ./ (sqrt(2*pi) .* sigma);
end

function print_bootstrap_summary(name, x)
    x = x(~isnan(x));
    if isempty(x)
        fprintf('%s: no valid bootstrap draws\n', name);
        return
    end

    med = median(x);
    lo  = prctile(x, 2.5);
    hi  = prctile(x, 97.5);

    p_le0 = mean(x <= 0);
    p_ge0 = mean(x >= 0);
    pval  = 2 * min(p_le0, p_ge0);
    pval  = min(pval, 1);

    fprintf('%s: median = %.4f, 95%% CI = [%.4f, %.4f], p ≈ %.4f\n', ...
        name, med, lo, hi, pval);
end