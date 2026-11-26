from enum import Enum


class Signal(Enum):
    positive = 'positive'
    neutral = 'neutral'
    negative = 'negative'


def draw_signal(rand, state=1):
    """Draw a signal conditional on the binary state.

    Positive and negative signal probabilities are reversed in state 0; a
    neutral signal has probability 0.25 in either state.
    """
    positive_probability = 0.45 if state == 1 else 0.30
    neutral_cutoff = positive_probability + 0.25

    if rand < positive_probability:
        return Signal.positive
    if rand < neutral_cutoff:
        return Signal.neutral
    return Signal.negative
