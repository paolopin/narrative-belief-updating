# Returns True if stopping condition is met
def should_stop(belief, threshold):
    belief = round(belief, 10)
    return (belief <= threshold[0]) or (belief >= threshold[1])
