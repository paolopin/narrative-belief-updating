import random

from decision_maker import DecisionMaker
from signal_technology import draw_signal
from stopping import should_stop


def normalize_threshold(threshold):
    if isinstance(threshold, tuple):
        return threshold

    distance_from_center = float(threshold)
    lower_threshold = 0.5 - distance_from_center
    upper_threshold = 0.5 + distance_from_center
    return lower_threshold, upper_threshold


def simulate_decision_time(update_rule, threshold, horizon):
    """Simulate one belief path until it crosses the stopping threshold."""
    if update_rule is None:
        print('Invalid Update Rule')
        return 0

    threshold = normalize_threshold(threshold)
    game = DecisionMaker(update_rule)

    rounds = 1

    generator = random.Random()
    for _ in range(horizon - 1):
        rand = round(generator.random(), 2)

        signal = draw_signal(rand)
        game.update(signal)
        rounds += 1
        if should_stop(game.belief, threshold):
            break

    return rounds
