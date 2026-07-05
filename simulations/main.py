import csv
import math
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

from simulation import normalize_threshold, simulate_decision_time
from update_rules import factory

UPDATE_TYPES = [
    'bayesian',
    'bayesian_reset_urn',
    'bayesian_reset_story',
    'bayesian_reset_story_no_info',
]
THRESHOLD_LEVELS = [0.3, 0.4, 0.45]
SUMMARY_METRICS = ['mean', 'ci_lower', 'ci_upper', 'median', 'p75', 'p90', 'p95']



def monte_carlo_wrapper(n_runs, update_type, threshold, horizon):
    # Run one Monte Carlo experiment for a given update rule and stopping threshold.
    update_rule = factory(update_type)
    lower_threshold, upper_threshold = normalize_threshold(threshold)
    final_rounds = []

    for _ in range(n_runs):
        simulation_rounds = simulate_decision_time(
            update_rule,
            threshold=threshold,
            horizon=horizon,
        )
        final_rounds.append(simulation_rounds)

    average_rounds = sum(final_rounds) / len(final_rounds)
    squared_diffs = [(rounds - average_rounds) ** 2 for rounds in final_rounds]
    sample_variance = sum(squared_diffs) / (len(final_rounds) - 1)
    standard_error = math.sqrt(sample_variance / len(final_rounds))
    ci_margin = 1.96 * standard_error
    ci_lower = average_rounds - ci_margin
    ci_upper = average_rounds + ci_margin
    sorted_rounds = sorted(final_rounds)
    median_rounds = quantile(sorted_rounds, 0.50)
    p75_rounds = quantile(sorted_rounds, 0.75)
    p90_rounds = quantile(sorted_rounds, 0.90)
    p95_rounds = quantile(sorted_rounds, 0.95)

    summary = {
        'update_type': update_type,
        'threshold': threshold,
        'lower_threshold': lower_threshold,
        'upper_threshold': upper_threshold,
        'mean': average_rounds,
        'ci_lower': ci_lower,
        'ci_upper': ci_upper,
        'median': median_rounds,
        'p75': p75_rounds,
        'p90': p90_rounds,
        'p95': p95_rounds,
    }

    return final_rounds, summary


def quantile(sorted_values, probability):
    position = (len(sorted_values) - 1) * probability
    lower_index = math.floor(position)
    upper_index = math.ceil(position)

    if lower_index == upper_index:
        return sorted_values[lower_index]

    lower_value = sorted_values[lower_index]
    upper_value = sorted_values[upper_index]
    weight = position - lower_index
    return lower_value + weight * (upper_value - lower_value)


def threshold_label(threshold):
    return f'{threshold:.2f}'.replace('.', '_')


def plot_histograms(results_by_rule, threshold):
    rule_names = list(results_by_rule.keys())
    n_plots = len(rule_names)
    n_cols = 2
    n_rows = math.ceil(n_plots / n_cols)

    all_rounds = [rounds for results in results_by_rule.values() for rounds in results]
    min_round = min(all_rounds)
    max_round = max(all_rounds)
    bins = range(min_round, max_round + 2)

    fig, axes = plt.subplots(n_rows, n_cols, figsize=(12, 4 * n_rows), sharex=True, sharey=True)
    axes = axes.flatten()

    for ax, rule_name in zip(axes, rule_names):
        rounds = results_by_rule[rule_name]
        average_rounds = sum(rounds) / len(rounds)

        ax.hist(rounds, bins=bins, edgecolor='black', alpha=0.75)
        ax.axvline(average_rounds, color='crimson', linestyle='--', linewidth=1.5)
        ax.set_title(rule_name)
        ax.set_xlabel('Final Rounds')
        ax.set_ylabel('Frequency')

    for ax in axes[n_plots:]:
        ax.axis('off')

    lower_threshold, upper_threshold = normalize_threshold(threshold)
    fig.suptitle(
        f'Stopping Time Distributions by Update Rule '
        f'(threshold={threshold:.2f}, bounds=({lower_threshold:.2f}, {upper_threshold:.2f}))'
    )
    fig.tight_layout()
    fig.subplots_adjust(top=0.92)

    output_path = Path(f'stopping_time_histograms_threshold_{threshold_label(threshold)}.png')
    fig.savefig(output_path, dpi=300)
    plt.close(fig)


def plot_ecdf(results_by_rule, threshold):
    fig, ax = plt.subplots(figsize=(10, 6))

    for rule_name, rounds in results_by_rule.items():
        sorted_rounds = sorted(rounds)
        ecdf_y = [(index + 1) / len(sorted_rounds) for index in range(len(sorted_rounds))]
        ax.step(sorted_rounds, ecdf_y, where='post', linewidth=2, label=rule_name)

    lower_threshold, upper_threshold = normalize_threshold(threshold)
    ax.set_title(
        f'ECDF of Stopping Times by Update Rule '
        f'(threshold={threshold:.2f}, bounds=({lower_threshold:.2f}, {upper_threshold:.2f}))'
    )
    ax.set_xlabel('Final Rounds')
    ax.set_ylabel('Cumulative Share of Simulations')
    ax.set_ylim(0, 1)
    ax.legend()
    ax.grid(alpha=0.3)

    output_path = Path(f'stopping_time_ecdf_threshold_{threshold_label(threshold)}.png')
    fig.tight_layout()
    fig.savefig(output_path, dpi=300)
    plt.close(fig)


def save_summary_table(summary_rows):
    output_path = Path('stopping_time_summary.csv')
    fieldnames = [
        'update_type',
        'threshold',
        'lower_threshold',
        'upper_threshold',
        'mean',
        'ci_lower',
        'ci_upper',
        'median',
        'p75',
        'p90',
        'p95',
    ]

    with output_path.open('w', newline='') as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(summary_rows)


def save_metric_tables(summary_rows):
    for metric in SUMMARY_METRICS:
        output_path = Path(f'stopping_time_{metric}_by_threshold.csv')
        fieldnames = ['update_type'] + [f'{threshold:.2f}' for threshold in THRESHOLD_LEVELS]

        with output_path.open('w', newline='') as csv_file:
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
            writer.writeheader()

            for update_type in UPDATE_TYPES:
                row = {'update_type': update_type}
                for threshold in THRESHOLD_LEVELS:
                    matching_summary = next(
                        summary
                        for summary in summary_rows
                        if summary['update_type'] == update_type
                        and summary['threshold'] == threshold
                    )
                    row[f'{threshold:.2f}'] = f"{matching_summary[metric]:.4f}"
                writer.writerow(row)

def save_latex_table(summary_rows):
    output_path = Path('stopping_time_table.tex')

    header_cells = ['Update rule']
    for threshold in THRESHOLD_LEVELS:
        lower_threshold, upper_threshold = normalize_threshold(threshold)
        header_cells.append(f'$({lower_threshold:.2f}, {upper_threshold:.2f})$')

    lines = [
        '\\begin{table}[htbp]',
        '\\centering',
        '\\caption{Stopping-time quantiles by update rule and threshold bounds. Cells report $P50$, $P75$, $P90$, $P95$, with the mean in parentheses.}',
        '\\label{tab:stopping-time-quantiles}',
        '\\begin{tabular}{lccc}',
        '\\hline',
        ' & '.join(header_cells) + ' \\\\',
        '\\hline',
    ]

    for update_type in UPDATE_TYPES:
        row_cells = [update_type.replace('_', '\\_')]
        for threshold in THRESHOLD_LEVELS:
            matching_summary = next(
                summary
                for summary in summary_rows
                if summary['update_type'] == update_type and summary['threshold'] == threshold
            )
            row_cells.append(
                '\\shortstack[l]{'
                f"P50 {matching_summary['median']:.2f}\\\\"
                f"P75 {matching_summary['p75']:.2f}\\\\"
                f"P90 {matching_summary['p90']:.2f}\\\\"
                f"P95 {matching_summary['p95']:.2f}\\\\"
                f"({matching_summary['mean']:.2f})"
                '}'
            )

        lines.append(' & '.join(row_cells) + ' \\\\')

    lines.extend([
        '\\hline',
        '\\end{tabular}',
        '\\end{table}',
    ])

    output_path.write_text('\n'.join(lines) + '\n')


# Run the simulations across all update rules and threshold levels, then save outputs.
summary_rows = []
for threshold in THRESHOLD_LEVELS:
    results_by_rule = {}
    for update_type in UPDATE_TYPES:
        final_rounds, summary = monte_carlo_wrapper(
            n_runs=10000,
            update_type=update_type,
            threshold=threshold,
            horizon=10000,
        )
        results_by_rule[update_type] = final_rounds
        summary_rows.append(summary)

    plot_histograms(results_by_rule, threshold)
    plot_ecdf(results_by_rule, threshold)

save_summary_table(summary_rows)
save_metric_tables(summary_rows)
save_latex_table(summary_rows)
