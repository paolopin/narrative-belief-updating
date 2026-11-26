"""Monte Carlo experiments and statistical summaries."""

import math
import random

from tqdm import tqdm

from decision_maker import DecisionMaker
from signal_technology import draw_signal
from simulation import normalize_threshold, simulate_decision
from update_rules import bayesian_update, factory


def signal_rng_for_run(seed, run_index):
    """Return the common signal RNG for a run, identical across rules."""
    return random.Random(seed + run_index)


def reset_rng_for_run(seed, update_types, update_type, run_index):
    """Return a rule-specific RNG used only for probabilistic resets."""
    rule_index = update_types.index(update_type)
    return random.Random(seed + 1_000_000 + 100_000 * rule_index + run_index)


def quantile(sorted_values, probability):
    position = (len(sorted_values) - 1) * probability
    lower_index = math.floor(position)
    upper_index = math.ceil(position)
    if lower_index == upper_index:
        return sorted_values[lower_index]
    weight = position - lower_index
    return (
        sorted_values[lower_index]
        + weight * (sorted_values[upper_index] - sorted_values[lower_index])
    )


def simulate_stopping_times(
    n_runs,
    update_type,
    threshold,
    max_signals,
    seed,
    update_types,
    true_state,
):
    """Run one stopping-time Monte Carlo experiment."""
    lower_threshold, upper_threshold = normalize_threshold(threshold)
    final_rounds = []
    outcomes = []

    description = f'Stopping | {update_type} | threshold={threshold:.2f}'
    for run_index in tqdm(range(n_runs), desc=description, unit='run'):
        signal_rng = signal_rng_for_run(seed, run_index)
        reset_rng = reset_rng_for_run(seed, update_types, update_type, run_index)
        result = simulate_decision(
            factory(update_type, rng=reset_rng),
            threshold=threshold,
            horizon=max_signals,
            rng=signal_rng,
            state=true_state,
        )
        final_rounds.append(result.rounds)
        outcomes.append(result)

    average_rounds = sum(final_rounds) / len(final_rounds)
    sample_variance = sum(
        (rounds - average_rounds) ** 2 for rounds in final_rounds
    ) / (len(final_rounds) - 1)
    ci_margin = 1.96 * math.sqrt(sample_variance / len(final_rounds))
    sorted_rounds = sorted(final_rounds)

    stopped_outcomes = [outcome for outcome in outcomes if outcome.stopped]
    correct_count = sum(
        outcome.decision == outcome.state for outcome in stopped_outcomes
    )
    incorrect_count = len(stopped_outcomes) - correct_count
    terminal_brier = sum(
        (outcome.final_belief - outcome.state) ** 2 for outcome in outcomes
    ) / n_runs
    full_history_brier = sum(
        (outcome.full_history_belief - outcome.state) ** 2
        for outcome in outcomes
    ) / n_runs

    summary = {
        'update_type': update_type,
        'threshold': threshold,
        'lower_threshold': lower_threshold,
        'upper_threshold': upper_threshold,
        'mean': average_rounds,
        'ci_lower': average_rounds - ci_margin,
        'ci_upper': average_rounds + ci_margin,
        'median': quantile(sorted_rounds, 0.50),
        'p75': quantile(sorted_rounds, 0.75),
        'p90': quantile(sorted_rounds, 0.90),
        'p95': quantile(sorted_rounds, 0.95),
        'stop_rate': len(stopped_outcomes) / n_runs,
        'decision_accuracy': (
            correct_count / len(stopped_outcomes) if stopped_outcomes else math.nan
        ),
        'correct_decision_rate': correct_count / n_runs,
        'incorrect_decision_rate': incorrect_count / n_runs,
        'terminal_brier_score': terminal_brier,
        'full_history_brier_score': full_history_brier,
        'excess_brier_score': terminal_brier - full_history_brier,
        'full_history_belief_mae': sum(
            abs(outcome.final_belief - outcome.full_history_belief)
            for outcome in outcomes
        ) / n_runs,
    }
    return final_rounds, summary


def simulate_fixed_horizon_brier(
    n_runs,
    update_type,
    horizons,
    seed,
    update_types,
    numerical_tolerance,
    true_state,
):
    """Evaluate time-average belief accuracy over fixed signal horizons."""
    horizons = sorted(set(horizons))
    if not horizons or horizons[0] <= 0:
        raise ValueError('Fixed horizons must be positive integers')

    brier_by_horizon = {horizon: [] for horizon in horizons}
    benchmark_by_horizon = {horizon: [] for horizon in horizons}

    description = f'Brier | {update_type} | T={horizons[-1]}'
    for run_index in tqdm(range(n_runs), desc=description, unit='run'):
        signal_rng = signal_rng_for_run(seed, run_index)
        reset_rng = reset_rng_for_run(seed, update_types, update_type, run_index)
        game = DecisionMaker(factory(update_type, rng=reset_rng))
        full_history_belief = 0.5
        cumulative_brier = 0.0
        cumulative_benchmark_brier = 0.0

        for signal_number in range(1, horizons[-1] + 1):
            signal = draw_signal(signal_rng.random(), state=true_state)
            game.update(signal)
            full_history_belief = bayesian_update(full_history_belief, signal)
            if (
                update_type == 'bayesian'
                and abs(game.belief - full_history_belief) > numerical_tolerance
            ):
                raise AssertionError(
                    'Bayesian rule diverged from the full-history posterior '
                    f'in run {run_index}, period {signal_number}'
                )

            cumulative_brier += (game.belief - true_state) ** 2
            cumulative_benchmark_brier += (full_history_belief - true_state) ** 2
            if signal_number in brier_by_horizon:
                brier_by_horizon[signal_number].append(
                    cumulative_brier / signal_number
                )
                benchmark_by_horizon[signal_number].append(
                    cumulative_benchmark_brier / signal_number
                )

    rows = []
    for horizon in horizons:
        brier_values = brier_by_horizon[horizon]
        benchmark_values = benchmark_by_horizon[horizon]
        mean_brier = sum(brier_values) / n_runs
        benchmark_brier = sum(benchmark_values) / n_runs
        sample_variance = sum(
            (value - mean_brier) ** 2 for value in brier_values
        ) / (n_runs - 1)
        ci_margin = 1.96 * math.sqrt(sample_variance / n_runs)
        rows.append({
            'update_type': update_type,
            'horizon': horizon,
            'brier_score': mean_brier,
            'ci_lower': mean_brier - ci_margin,
            'ci_upper': mean_brier + ci_margin,
            'full_history_brier_score': benchmark_brier,
            'excess_brier_score': mean_brier - benchmark_brier,
        })
    return rows
