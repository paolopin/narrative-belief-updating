"""Configuration and entry point for the simulation pipeline."""

from pathlib import Path

from monte_carlo import simulate_fixed_horizon_brier, simulate_stopping_times
from reporting import (
    plot_ecdf,
    plot_histograms,
    save_appendix_table,
    save_fixed_horizon_summary,
    save_main_results,
    save_stopping_summary,
)
from validation import validate_fixed_horizon_results


# Experiment configuration
N_RUNS = 100000
SIMULATION_SEED = 42
TRUE_STATE = 1
MAX_SIGNALS = 10000
NUMERICAL_TOLERANCE = 1e-12

THRESHOLD_LEVELS = [0.30, 0.40, 0.45]
BRIER_HORIZONS = [10, 50, 100]
UPDATE_TYPES = [
    'bayesian',
    'bayesian_reset_urn',
    'bayesian_reset_story',
    'bayesian_reset_story_no_info',
]

# Output directories
PROJECT_DIR = Path(__file__).resolve().parent
RESULTS_DIR = PROJECT_DIR / 'results'
DATA_DIR = RESULTS_DIR / 'data'
TABLES_DIR = RESULTS_DIR / 'tables'
FIGURES_DIR = RESULTS_DIR / 'figures'


def prepare_output_directories():
    for directory in (DATA_DIR, TABLES_DIR, FIGURES_DIR):
        directory.mkdir(parents=True, exist_ok=True)


def run_stopping_experiments():
    summary_rows = []
    for threshold in THRESHOLD_LEVELS:
        distributions = {}
        for update_type in UPDATE_TYPES:
            rounds, summary = simulate_stopping_times(
                n_runs=N_RUNS,
                update_type=update_type,
                threshold=threshold,
                max_signals=MAX_SIGNALS,
                seed=SIMULATION_SEED,
                update_types=UPDATE_TYPES,
                true_state=TRUE_STATE,
            )
            distributions[update_type] = rounds
            summary_rows.append(summary)

        plot_histograms(distributions, threshold, FIGURES_DIR)
        plot_ecdf(distributions, threshold, FIGURES_DIR)
    return summary_rows


def run_brier_experiments():
    rows = []
    for update_type in UPDATE_TYPES:
        rows.extend(
            simulate_fixed_horizon_brier(
                n_runs=N_RUNS,
                update_type=update_type,
                horizons=BRIER_HORIZONS,
                seed=SIMULATION_SEED,
                update_types=UPDATE_TYPES,
                numerical_tolerance=NUMERICAL_TOLERANCE,
                true_state=TRUE_STATE,
            )
        )
    return rows


def main():
    prepare_output_directories()
    stopping_rows = run_stopping_experiments()
    brier_rows = run_brier_experiments()

    validate_fixed_horizon_results(
        rows=brier_rows,
        horizons=BRIER_HORIZONS,
        seed=SIMULATION_SEED,
        n_runs=N_RUNS,
        numerical_tolerance=NUMERICAL_TOLERANCE,
        report_path=DATA_DIR / 'validation_report.txt',
        true_state=TRUE_STATE,
    )

    save_stopping_summary(stopping_rows, DATA_DIR / 'stopping_time_summary.csv')
    save_fixed_horizon_summary(
        brier_rows,
        DATA_DIR / 'fixed_horizon_brier_summary.csv',
    )
    save_appendix_table(
        stopping_rows,
        UPDATE_TYPES,
        THRESHOLD_LEVELS,
        TABLES_DIR / 'stopping_time_quantiles_appendix.tex',
    )
    save_main_results(
        stopping_rows,
        brier_rows,
        UPDATE_TYPES,
        THRESHOLD_LEVELS,
        BRIER_HORIZONS,
        DATA_DIR,
        TABLES_DIR,
    )


if __name__ == '__main__':
    main()
