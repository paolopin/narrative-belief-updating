import random
from signal_technology import Signal

# reset to 0.5 estimated probabilites
D_GRID = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50]

RESET_URN = [
    0.379826, 0.3394645, 0.3010099, 0.2647449, 0.2308751,
    0.1995461, 0.170858, 0.1448728, 0.1216135, 0.1010586
]

RESET_STORY = [
    0.3315825, 0.3170116, 0.3027365, 0.2887713, 0.2751279,
    0.2618174, 0.2488492, 0.2362315, 0.2239718, 0.2120764
]

RESET_STORY_NO_INFO = [
    0.1333796, 0.1001014, 0.0732868, 0.0523899, 0.036611,
    0.0250246, 0.0167206, 0.010901, 0.0069172, 0.0042629
]
# Reset to 0.5 probability function
def make_reset_probability_function(reset_values):
    def reset_probability(distance):
        d = max(D_GRID[0], min(D_GRID[-1], distance))

        for i in range(len(D_GRID) - 1):
            x0 = D_GRID[i]
            x1 = D_GRID[i + 1]

            if x0 <= d <= x1:
                y0 = reset_values[i]
                y1 = reset_values[i + 1]

                weight = (d - x0) / (x1 - x0)
                p = y0 + weight * (y1 - y0)

                return max(0.0, min(1.0, p))

        return max(0.0, min(1.0, reset_values[-1]))

    return reset_probability

reset_prob_urn = make_reset_probability_function(RESET_URN)
reset_prob_story = make_reset_probability_function(RESET_STORY)
reset_prob_story_no_info = make_reset_probability_function(RESET_STORY_NO_INFO)

# Simple update
# Adds 0.1 for positive signal, -0.1 for negative, no change for neutral
def basic_update(belief, signal):
    if signal == Signal.positive: 
        belief += 0.1
    elif signal == Signal.negative:
        belief -= 0.1
    return min(1.0, max(0.0, belief))

def bayesian_update(belief, signal):
    if signal == Signal.positive:
        likelihood_state_1 = 0.45
        likelihood_state_0 = 0.30

    elif signal == Signal.negative:
        likelihood_state_1 = 0.30
        likelihood_state_0 = 0.45

    elif signal == Signal.neutral:
        return belief

    else:
        return belief

    numerator = likelihood_state_1 * belief
    denominator = likelihood_state_1 * belief + likelihood_state_0 * (1 - belief)

    return numerator / denominator

# Bayesian update for positive-negative signals and reset to 0.5 for neutral signals.
def make_bayesian_reset_rule(reset_probability_function):
    def update_rule(belief, signal):
        if signal in [Signal.positive, Signal.negative]:
            return bayesian_update(belief, signal)

        if signal == Signal.neutral:
            distance = abs(belief - 0.5)
            p_reset = reset_probability_function(distance)

            if random.random() < p_reset:
                return 0.5

            return belief

        return belief

    return update_rule
bayesian_reset_urn = make_bayesian_reset_rule(reset_prob_urn)
bayesian_reset_story = make_bayesian_reset_rule(reset_prob_story)
bayesian_reset_story_no_info = make_bayesian_reset_rule(reset_prob_story_no_info)

def factory(update_type, **kwargs):
    if update_type == 'basic':
        return basic_update
    elif update_type == 'bayesian':
        return bayesian_update
    elif update_type == 'bayesian_reset_urn':
        return bayesian_reset_urn
    elif update_type == 'bayesian_reset_story':
        return bayesian_reset_story
    elif update_type == 'bayesian_reset_story_no_info':
        return bayesian_reset_story_no_info
    return None
