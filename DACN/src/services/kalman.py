import numpy as np
import pandas as pd

class SimpleKalmanFilter:
    def __init__(self, initial_state, initial_covariance, process_noise, measurement_noise):
        self.state = initial_state
        self.covariance = initial_covariance
        self.process_noise = process_noise
        self.measurement_noise = measurement_noise

    def update(self, measurement):
        # Prediction step
        predicted_state = self.state
        predicted_covariance = self.covariance + self.process_noise

        # Update step
        kalman_gain = predicted_covariance / (predicted_covariance + self.measurement_noise)
        self.state = predicted_state + kalman_gain * (measurement - predicted_state)
        self.covariance = (1 - kalman_gain) * predicted_covariance
        
        return self.state

def apply_kalman_filter(data: pd.Series) -> pd.Series:
    if data.empty:
        return pd.Series()
        
    # Initialize Kalman Filter parameters
    initial_state = data.iloc[0]
    initial_covariance = 1.0
    process_noise = 0.01
    measurement_noise = 1.0
    
    kf = SimpleKalmanFilter(initial_state, initial_covariance, process_noise, measurement_noise)
    
    kalman_estimates = []
    for measurement in data.values:
        estimate = kf.update(measurement)
        kalman_estimates.append(estimate)
        
    return pd.Series(kalman_estimates, index=data.index), kf
