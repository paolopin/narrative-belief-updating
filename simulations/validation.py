"""Reproducibility and benchmark checks."""


def validate_fixed_horizon_results(
    rows,
    horizons,
    seed,
    n_runs,
    numerical_tolerance,
    report_path,
    true_state,
):
    """Fail loudly if common-history or Bayesian-benchmark checks do not hold."""
    checks = []
    for horizon in horizons:
        horizon_rows = [row for row in rows if row['horizon'] == horizon]
        benchmark_values = {
            row['full_history_brier_score'] for row in horizon_rows
        }
        if len(benchmark_values) != 1:
            raise AssertionError(
                f'Full-history benchmark differs across rules at T={horizon}'
            )
        checks.append(
            f'PASS: identical full-history benchmark across rules at T={horizon}'
        )

        bayesian_row = next(
            row for row in horizon_rows if row['update_type'] == 'bayesian'
        )
        if abs(bayesian_row['excess_brier_score']) > numerical_tolerance:
            raise AssertionError(f'Bayesian excess Brier is not zero at T={horizon}')
        checks.append(f'PASS: Bayesian excess Brier equals zero at T={horizon}')

    report_lines = [
        'Fixed-horizon Brier validation',
        f'Simulation seed: {seed}',
        f'Number of runs: {n_runs}',
        f'True state: {true_state}',
        '',
        'The signal RNG is a deterministic function of run index only, so every',
        'updating rule receives the same signal sequence within a run. Reset',
        'randomness uses a separate rule-specific RNG and cannot alter signals.',
        '',
        'During simulation, the Bayesian rule is checked against the full-history',
        'posterior after every signal in every run.',
        '',
        *checks,
    ]
    report_path.write_text('\n'.join(report_lines) + '\n')
