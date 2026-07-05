class DecisionMaker:
    def __init__(self, update_rule, belief=0.5):
        self.update_rule = update_rule
        self.belief = belief

    def update(self, signal):
        new_belief = self.update_rule(self.belief, signal)
        self.belief = new_belief
        return self.belief
