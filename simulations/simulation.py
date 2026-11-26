import random
from dataclasses import dataclass

from decision_maker import DecisionMaker
from signal_technology import draw_signal
from stopping import should_stop
from update_rules import bayesian_update


@dataclass(frozen=True)
class SimulationResult:
    rounds: int
    state: int
    stopped: bool
    decision: int | None
    final_belief: float
    full_history_belief: float


def normalize_threshold(threshold):
    if isinstance(threshold, tuple):
        return threshold

    distance_from_center = float(threshold)
    lower_threshold = 0.5 - distance_from_center
    upper_threshold = 0.5 + distance_from_center
    return lower_threshold, upper_threshold


def simulate_decision(update_rule, threshold, horizon, rng=None, state=1):
    """Simulate one path and retain accuracy and decision outcomes."""
    if update_rule is None:
        print('Invalid Update Rule')
        raise ValueError('Invalid update rule')

    threshold = normalize_threshold(threshold)
    game = DecisionMaker(update_rule)
    full_history_belief = 0.5
    rng = rng or random.Random()
    if state not in (0, 1):
        raise ValueError('state must be either 0 or 1')

    rounds = 0
    stopped = should_stop(game.belief, threshold)
    for _ in range(horizon):
        signal = draw_signal(rng.random(), state=state)
        game.update(signal)
        full_history_belief = bayesian_update(full_history_belief, signal)
        rounds += 1
        if should_stop(game.belief, threshold):
            stopped = True
            break

    decision = None
    if stopped:
        decision = int(game.belief >= threshold[1])

    return SimulationResult(
        rounds=rounds,
        state=state,
        stopped=stopped,
        decision=decision,
        final_belief=game.belief,
        full_history_belief=full_history_belief,
    )


def simulate_decision_time(update_rule, threshold, horizon):
    """Backward-compatible stopping-time-only interface."""
    return simulate_decision(update_rule, threshold, horizon).rounds
