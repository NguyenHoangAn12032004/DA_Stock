from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from src.data.loader import prepare_market_dataset


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download and preprocess market data.")
    parser.add_argument("--tickers", nargs="+", default=["AAPL", "NVDA", "GOOG"], help="Ticker symbols to download.")
    parser.add_argument("--start", type=str, default="2010-01-01", help="Start date (YYYY-MM-DD).")
    parser.add_argument("--end", type=str, default="2024-12-31", help="End date (YYYY-MM-DD).")
    parser.add_argument("--interval", type=str, default="1d", help="Data interval, e.g., 1d, 1wk.")
    parser.add_argument(
        "--dataset-path",
        type=Path,
        default=Path("data/processed/aapl_nvda_goog_daily.npz"),
        help="Output path for the processed dataset.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("data/processed"),
        help="Directory for per-ticker datasets when using --split-per-ticker.",
    )
    parser.add_argument("--feature-window", type=int, default=50, help="Rolling window for indicators.")
    parser.add_argument(
        "--indicators",
        nargs="*",
        default=[
            "rsi",
            "macd",
            "stochastic",
            "williams_r",
            "roc",
            "bollinger",
            "atr",
            "adx",
            "obv",
            "mfi",
            "cci",
        ],
        help="Technical indicators to include.",
    )
    parser.add_argument("--train-ratio", type=float, default=0.8, help="Train split ratio.")
    parser.add_argument(
        "--split-per-ticker",
        action="store_true",
        help="Save an individual dataset for each ticker under --output-dir.",
    )
    parser.add_argument(
        "--extended-features",
        action="store_true",
        help="Include extended price/volume factors during feature engineering.",
    )
    parser.add_argument(
        "--calibration-enabled",
        action="store_true",
        help="Apply probability calibration for direction_prob using a prefit calibrator (joblib).",
    )
    parser.add_argument(
        "--calibration-path",
        type=Path,
        default=None,
        help="Path to calibration artifact (.joblib) with per-asset calibrators.",
    )
    parser.add_argument(
        "--calibrate-only-after-split",
        action="store_true",
        help="If set, apply calibration only on validation/test portion (indices >= split_index) to avoid leakage.",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=None,
        help="Path to YAML config file. If provided, other args are ignored/overridden.",
    )
    return parser.parse_args()


def update_dataset_from_config(config_path: Path):
    """Update dataset based on a YAML config file."""
    import yaml
    with open(config_path, "r") as f:
        cfg = yaml.safe_load(f)
    
    data_cfg = cfg["data"]
    
    prepare_market_dataset(
        tickers=data_cfg["tickers"],
        start=data_cfg["start"],
        end=data_cfg["end"],
        interval=data_cfg.get("interval", "1d"),
        dataset_path=Path(data_cfg["dataset_path"]),
        feature_window=data_cfg.get("feature_window", 50),
        indicators=data_cfg.get("technical_indicators", []),
        train_ratio=data_cfg.get("train_ratio", 0.8),
        include_extended_features=data_cfg.get("extended_features", False)
    )
    print(f"Updated dataset at {data_cfg['dataset_path']}")


def main() -> None:
    args = parse_args()
    
    if args.config:
        update_dataset_from_config(args.config)
        return

    if args.split_per_ticker:
        args.output_dir.mkdir(parents=True, exist_ok=True)
        for ticker in args.tickers:
            ticker_dir = args.output_dir / ticker.lower()
            ticker_dir.mkdir(parents=True, exist_ok=True)
            dataset_path = ticker_dir / f"{ticker.lower()}_{args.interval}.npz"
            prepare_market_dataset(
                tickers=[ticker],
                start=args.start,
                end=args.end,
                interval=args.interval,
                dataset_path=dataset_path,
                feature_window=args.feature_window,
                indicators=args.indicators,
                train_ratio=args.train_ratio,
                include_extended_features=args.extended_features,
                calibration_enabled=args.calibration_enabled,
                calibration_path=args.calibration_path,
                calibrate_only_after_split=args.calibrate_only_after_split,
            )
            print(f"Dataset saved to {dataset_path}")
    else:
        prepare_market_dataset(
            tickers=args.tickers,
            start=args.start,
            end=args.end,
            interval=args.interval,
            dataset_path=args.dataset_path,
            feature_window=args.feature_window,
            indicators=args.indicators,
            train_ratio=args.train_ratio,
            include_extended_features=args.extended_features,
            calibration_enabled=args.calibration_enabled,
            calibration_path=args.calibration_path,
            calibrate_only_after_split=args.calibrate_only_after_split,
        )
        print(f"Dataset saved to {args.dataset_path}")


if __name__ == "__main__":
    main()
