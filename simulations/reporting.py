"""Writers for figures, machine-readable results, and LaTeX tables."""

import csv
import math

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

from simulation import normalize_threshold


ACCURACY_METRICS = [
    'stop_rate',
    'decision_accuracy',
    'correct_decision_rate',
    'incorrect_decision_rate',
    'terminal_brier_score',
    'full_history_brier_score',
    'excess_brier_score',
    'full_history_belief_mae',
]

RULE_LABELS = {
    'bayesian': 'Bayesian',
    'bayesian_reset_urn': r'Reset--\Control',
    'bayesian_reset_story': r'Reset--\Narrative',
    'bayesian_reset_story_no_info': r'Reset--\NarrativeNI',
}


def threshold_label(threshold):
    return f'{threshold:.2f}'.replace('.', '_')


def plot_histograms(results_by_rule, threshold, figures_dir):
    rule_names = list(results_by_rule)
    n_plots = len(rule_names)
    n_cols = 2
    n_rows = math.ceil(n_plots / n_cols)
    all_rounds = [value for results in results_by_rule.values() for value in results]
    bins = range(min(all_rounds), max(all_rounds) + 2)

    fig, axes = plt.subplots(
        n_rows, n_cols, figsize=(12, 4 * n_rows), sharex=True, sharey=True
    )
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

    lower, upper = normalize_threshold(threshold)
    fig.suptitle(
        'Stopping Time Distributions by Update Rule '
        f'(threshold={threshold:.2f}, bounds=({lower:.2f}, {upper:.2f}))'
    )
    fig.tight_layout()
    fig.subplots_adjust(top=0.92)
    fig.savefig(
        figures_dir / f'stopping_time_histograms_threshold_{threshold_label(threshold)}.png',
        dpi=300,
    )
    plt.close(fig)


def plot_ecdf(results_by_rule, threshold, figures_dir):
    fig, ax = plt.subplots(figsize=(10, 6))
    for rule_name, rounds in results_by_rule.items():
        sorted_rounds = sorted(rounds)
        ecdf_y = [(index + 1) / len(sorted_rounds) for index in range(len(sorted_rounds))]
        ax.step(sorted_rounds, ecdf_y, where='post', linewidth=2, label=rule_name)

    lower, upper = normalize_threshold(threshold)
    ax.set_title(
        'ECDF of Stopping Times by Update Rule '
        f'(threshold={threshold:.2f}, bounds=({lower:.2f}, {upper:.2f}))'
    )
    ax.set_xlabel('Final Rounds')
    ax.set_ylabel('Cumulative Share of Simulations')
    ax.set_ylim(0, 1)
    ax.legend()
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(
        figures_dir / f'stopping_time_ecdf_threshold_{threshold_label(threshold)}.png',
        dpi=300,
    )
    plt.close(fig)


def save_stopping_summary(rows, output_path):
    fieldnames = [
        'update_type', 'threshold', 'lower_threshold', 'upper_threshold',
        'mean', 'ci_lower', 'ci_upper', 'median', 'p75', 'p90', 'p95',
        *ACCURACY_METRICS,
    ]
    with output_path.open('w', newline='') as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def save_fixed_horizon_summary(rows, output_path):
    fieldnames = [
        'update_type', 'horizon', 'brier_score', 'ci_lower', 'ci_upper',
        'full_history_brier_score', 'excess_brier_score',
    ]
    with output_path.open('w', newline='') as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def save_appendix_table(summary_rows, update_types, thresholds, output_path):
    header_cells = ['Update rule']
    for threshold in thresholds:
        lower, upper = normalize_threshold(threshold)
        header_cells.append(f'$({lower:.2f}, {upper:.2f})$')
    lines = [
        '\\begin{table}[htbp]', '\\centering',
        '\\caption{Stopping-time quantiles by update rule and threshold bounds. Cells report $P50$, $P75$, $P90$, $P95$, with the mean in parentheses.}',
        '\\label{tab:stopping-time-quantiles}', '\\begin{tabular}{lccc}',
        '\\hline', ' & '.join(header_cells) + ' \\\\', '\\hline',
    ]
    for update_type in update_types:
        row_cells = [update_type.replace('_', '\\_')]
        for threshold in thresholds:
            row = next(
                item for item in summary_rows
                if item['update_type'] == update_type and item['threshold'] == threshold
            )
            row_cells.append(
                '\\shortstack[l]{'
                f"P50 {row['median']:.2f}\\\\"
                f"P75 {row['p75']:.2f}\\\\"
                f"P90 {row['p90']:.2f}\\\\"
                f"P95 {row['p95']:.2f}\\\\"
                f"({row['mean']:.2f})" + '}'
            )
        lines.append(' & '.join(row_cells) + ' \\\\')
    lines.extend(['\\hline', '\\end{tabular}', '\\end{table}'])
    output_path.write_text('\n'.join(lines) + '\n')


def save_main_results(
    summary_rows,
    fixed_horizon_rows,
    update_types,
    thresholds,
    horizons,
    data_dir,
    tables_dir,
):
    """Save the paper's main table and its machine-readable sources."""
    stopping_rows = []
    for threshold in thresholds:
        for update_type in update_types:
            stopping = next(
                row for row in summary_rows
                if row['threshold'] == threshold and row['update_type'] == update_type
            )
            stopping_rows.append({
                'lower_threshold': stopping['lower_threshold'],
                'upper_threshold': stopping['upper_threshold'],
                'update_type': update_type,
                'mean_signals': stopping['mean'],
                'median_signals': stopping['median'],
            })
    with (data_dir / 'main_stopping_times.csv').open('w', newline='') as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=list(stopping_rows[0]))
        writer.writeheader()
        writer.writerows(stopping_rows)

    accuracy_rows = []
    for update_type in update_types:
        row = {'update_type': update_type}
        for horizon in horizons:
            result = next(
                item for item in fixed_horizon_rows
                if item['update_type'] == update_type and item['horizon'] == horizon
            )
            row[f'excess_brier_T{horizon}'] = result['excess_brier_score']
        accuracy_rows.append(row)
    with (data_dir / 'main_belief_accuracy.csv').open('w', newline='') as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=list(accuracy_rows[0]))
        writer.writeheader()
        writer.writerows(accuracy_rows)

    lines = [
        r'\begin{table}[H]', r'\centering\small',
        r'\caption{Stopping times and excess Brier scores under alternative updating rules.}',
        '', r'\textit{Panel A: Stopping times}', '',
        r'\begin{tabular}{llcc}', r'\toprule',
        r'& & \multicolumn{2}{c}{Number of signals} \\',
        r'\cmidrule(lr){3-4}', r'Threshold & Update rule & Mean & $P_{50}$ \\',
        r'\midrule',
    ]
    for threshold_index, threshold in enumerate(thresholds):
        lower, upper = normalize_threshold(threshold)
        lines.append(rf'\multirow{{4}}{{*}}{{ $({lower:.2f}, {upper:.2f})$ }}')
        for update_type in update_types:
            row = next(
                item for item in stopping_rows
                if item['lower_threshold'] == lower and item['update_type'] == update_type
            )
            lines.append(
                f"& {RULE_LABELS[update_type]:<24} & {row['mean_signals']:.2f} "
                f"& {row['median_signals']:.0f} \\\\"
            )
        if threshold_index < len(thresholds) - 1:
            lines.extend([r'\addlinespace', ''])

    lines.extend([
        r'\bottomrule', r'\end{tabular}', '', r'\vspace{1em}', '',
        r'\textit{Panel B: Belief accuracy}', '', r'\begin{tabular}{lccc}',
        r'\toprule', r'& \multicolumn{3}{c}{Average excess Brier score} \\',
        r'\cmidrule(lr){2-4}',
        r'Update rule & $T=10$ & $T=50$ & $T=100$ \\', r'\midrule',
    ])
    for row in accuracy_rows:
        update_type = row['update_type']
        values = [
            '0.000' if update_type == 'bayesian'
            else f"{row[f'excess_brier_T{horizon}']:.3f}"
            for horizon in horizons
        ]
        lines.append(f"{RULE_LABELS[update_type]:<24} & " + ' & '.join(values) + r' \\')
    lines.extend([
        r'\bottomrule', r'\end{tabular}', '',
        r'\caption*{\footnotesize \textit{Note}: Panel A reports the mean and median number of signals required for beliefs to cross each decision threshold. Panel B reports average excess Brier scores relative to Bayesian updating over the first $T=10$, $50$, and $100$ signals, respectively. Excess Brier scores are calculated as the mean difference in squared prediction errors between each updating rule and the Bayesian benchmark, averaged across simulated signal sequences and periods $t=1,\ldots,T$. All updating rules are evaluated on the same signal sequences, and belief updating continues after any decision threshold is crossed. The excess Brier score is zero by construction for Bayesian updating.}',
        r'\label{tab:stopping_times}', r'\end{table}',
    ])
    (tables_dir / 'main_results.tex').write_text('\n'.join(lines) + '\n')
