from enum import Enum


class Signal(Enum):
    positive = 'positive'
    neutral = 'neutral'
    negative = 'negative'


def draw_signal(rand):
    if 0 <= rand < 0.45:
        return Signal.positive
    if 0.45 <= rand < 0.70:
        return Signal.neutral
    return Signal.negative
