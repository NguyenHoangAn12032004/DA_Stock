import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import confusion_matrix, ConfusionMatrixDisplay

def plot_confusion_matrix_direction(dataset, start_idx, end_idx, output_dir: Path):
    """
    Plots confusion matrix for direction prediction (Logistic Regression).
    Uses 'direction_prob' feature from dataset if available.
    """
    if "direction_prob" not in dataset.feature_names:
        print("Warning: 'direction_prob' not found in features. Skipping Confusion Matrix.")
        return

    dir_idx = dataset.feature_names.index("direction_prob")
    
    # Extract probabilities and actual returns for the evaluation period
    # features[t] predicts returns[t+1]
    # So we take features from start_idx to end_idx (exclusive of end_idx+1)
    # And returns from start_idx+1 to end_idx+1
    
    # Ensure indices are within bounds
    start = max(0, start_idx)
    end = min(len(dataset.dates) - 1, end_idx)
    
    if start >= end:
        print("Warning: Invalid evaluation range for Confusion Matrix.")
        return

    # Probabilities at time t
    probs = dataset.features[start:end, :, dir_idx]
    
    # Returns at time t+1
    actual_returns = dataset.returns[start+1 : end+1, :]
    
    # Flatten for all assets
    y_pred_prob = probs.flatten()
    y_true = (actual_returns > 0).astype(int).flatten()
    y_pred = (y_pred_prob > 0.5).astype(int)
    
    # Filter out NaNs if any
    mask = ~np.isnan(y_pred_prob) & ~np.isnan(actual_returns.flatten())
    y_true = y_true[mask]
    y_pred = y_pred[mask]
    
    if len(y_true) == 0:
        print("Warning: No valid data for Confusion Matrix.")
        return

    cm = confusion_matrix(y_true, y_pred, labels=[0, 1])
    disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=["Down", "Up"])
    
    plt.figure(figsize=(8, 6))
    # Plot without 'values_format' argument in plot() if it causes issues, 
    # but usually it's fine. If error, remove it.
    try:
        disp.plot(cmap=plt.cm.Blues, values_format='d')
    except TypeError:
        disp.plot(cmap=plt.cm.Blues)
        
    plt.title("Direction Prediction Confusion Matrix")
    plt.tight_layout()
    plt.savefig(output_dir / "direction_confusion_matrix.png", dpi=200)
    plt.close()


def plot_feature_importance_lr(dataset, output_dir: Path):
    """
    Retrains Logistic Regression on the training set to extract and plot feature importance.
    """
    # Identify training set
    split_idx = dataset.split_index
    if split_idx < 100:
        print("Warning: Training set too small for Feature Importance.")
        return

    # We need to exclude 'direction_prob' itself from the features used to train LR
    feature_names = dataset.feature_names
    if "direction_prob" in feature_names:
        feat_indices = [i for i, name in enumerate(feature_names) if name != "direction_prob"]
        feat_names_clean = [name for i, name in enumerate(feature_names) if name != "direction_prob"]
    else:
        feat_indices = list(range(len(feature_names)))
        feat_names_clean = feature_names

    # Prepare training data
    # features[t] predicts returns[t+1]
    # Use slicing to get all assets
    X_train = dataset.features[:split_idx-1, :, feat_indices]
    y_train_raw = dataset.returns[1:split_idx, :]
    
    # Flatten assets (time * assets, features)
    # X_train shape: (T, N, F) -> (T*N, F)
    X_train_flat = X_train.reshape(-1, len(feat_indices))
    y_train_flat = (y_train_raw > 0).astype(int).flatten()
    
    # Remove NaNs
    mask = ~np.isnan(X_train_flat).any(axis=1) & ~np.isnan(y_train_flat)
    X_train_flat = X_train_flat[mask]
    y_train_flat = y_train_flat[mask]
    
    if len(y_train_flat) == 0:
        print("Warning: No valid training data for Feature Importance.")
        return

    # Train LR
    try:
        clf = LogisticRegression(max_iter=1000, class_weight="balanced", solver="lbfgs")
        clf.fit(X_train_flat, y_train_flat)
        
        importance = clf.coef_[0]
        
        # Sort features by absolute importance
        indices = np.argsort(np.abs(importance))[-20:] # Top 20
        
        plt.figure(figsize=(10, 8))
        plt.barh(range(len(indices)), importance[indices], align='center')
        plt.yticks(range(len(indices)), [feat_names_clean[i] for i in indices])
        plt.xlabel("Coefficient Value")
        plt.title("Logistic Regression Feature Importance (Top 20)")
        plt.tight_layout()
        plt.savefig(output_dir / "feature_importance_lr.png", dpi=200)
        plt.close()
        
    except Exception as e:
        print(f"Error calculating feature importance: {e}")
