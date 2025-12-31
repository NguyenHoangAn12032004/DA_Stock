# RL Trading Pipeline for AAPL, NVDA, GOOG

This project trains single-asset PPO agents for AAPL, NVDA, and GOOG using a custom Gymnasium environment with probability-gated trade execution. It covers data ingestion, feature engineering (including a logistic regression direction model plus volume-sensitive indicators like MFI/CCI), environment modeling, policy tuning, parameter sweeps, and backtesting.

## Project Structure

```
.
├── data/                # Raw and processed market data
├── logs/                # TensorBoard and training logs (git-ignored)
├── models/              # Saved RL policy checkpoints (git-ignored; store locally or via LFS)
├── reports/figures/     # Generated plots (PNG)
├── reports/forward_paper/ # Forward-paper logs and metrics (git-keep placeholder)
├── reports/scenarios/   # Scenario configuration & outputs
├── reports/walkforward/ # Walk-forward evaluation artifacts
├── scripts/             # Entry-point scripts
└── src/                 # Source code packages
```

## Quickstart

1. Create a virtual environment and install dependencies:
   ```powershell
   python -m venv .venv
   .venv\Scripts\Activate.ps1
   pip install -r requirements.txt
   ```
2. Download data and preprocess the price history and engineered features:
   ```powershell
   python scripts\prepare_data.py --tickers AAPL NVDA GOOG --start 2010-01-01 --end 2024-12-31
   ```
3. Train an agent for a specific ticker (configs written per asset):
   ```powershell
   python scripts\train_agent.py --config configs\aapl.yaml
   ```
4. Evaluate a trained checkpoint and optionally render plots:
   ```powershell
   python scripts\evaluate_agent.py --config configs\aapl.yaml --plot
   ```
5. Sweep directional probability thresholds and trade penalties against a saved checkpoint to compare risk filters:
   ```powershell
   python scripts\sweep_direction_thresholds.py --config configs\goog.yaml --thresholds 0.72 0.74 0.76 --penalties 0.09 0.12 0.15
   ```
6. Launch a forward-paper run with explicit slippage modeling (3-month default horizon):
   ```powershell
   python scripts\run_forward_paper.py --config configs\goog.yaml --start-date 2025-01-02 --extra-slippage-bps 3
   ```
7. Produce walk-forward splits and earnings-gap scenarios to stress-test robustness:
   ```powershell
   python scripts\run_walkforward.py --config configs\goog.yaml
   python scripts\run_scenarios.py --config configs\goog.yaml --events reports\scenarios\events_template.json
   ```

## Run the Advice API (prod/limited) and WS gating

Server đọc cấu hình từ `configs/server_assets.yaml` để xác định asset nào ở chế độ prod/limited/disabled và tham số stream/advice.

1) Khởi động API:
   ```powershell
   E:\DACN\.venv\Scripts\python.exe scripts\run_api.py
   ```

2) Kiểm tra endpoints chính:
   - `GET /assets` — danh sách asset và mode
   - `GET /advice` — mặc định chỉ trả asset ở mode=prod (AAPL)
   - `GET /advice?include_limited=true` — bao gồm cả asset limited (NVDA)
   - `GET /tickers` và `GET /tickers?include_limited=true`

   Ví dụ nhanh với curl (PowerShell):
   ```powershell
   curl http://localhost:8000/assets
   curl http://localhost:8000/advice
   curl "http://localhost:8000/advice?include_limited=true"
   curl "http://localhost:8000/market/history?symbol=AAPL&days=10"
   curl "http://localhost:8000/market/summary?symbols=AAPL,NVDA,GOOG"
   # PPO (RL) latest signal from no-force/base config
   curl "http://localhost:8000/rl/predict?ticker=AAPL"
   ```

3) WebSocket realtime (NVDA đang limited, yêu cầu token):
   - Token cấu hình tại: `configs/server_assets.yaml` → `auth.limited_token`
   - Kết nối: `ws://localhost:8000/ws/market/NVDA?token=nvda-limited-demo-token-2025`

   Ví dụ Python (sử dụng websocket-client đã có trong requirements):
   ```powershell
   E:\DACN\.venv\Scripts\python.exe - << 'PY'
   import json, time
   from websocket import create_connection

   def listen(url, seconds=5):
      ws = create_connection(url)
      start = time.time()
      try:
         while time.time() - start < seconds:
            msg = ws.recv()
            print(msg)
      finally:
         ws.close()

   # AAPL (prod)
   listen("ws://localhost:8000/ws/market/AAPL", seconds=3)
   # NVDA (limited) – cần token
   listen("ws://localhost:8000/ws/market/NVDA?token=nvda-limited-demo-token-2025", seconds=3)
   PY
   ```

### PPO RL latest signal (optional)

Endpoint `/rl/predict` runs the PPO policy over the test segment to the most recent bar and returns the last-step signal.

- Defaults to config `configs/aapl_finetune_2025_ext_override_v3_best_no_force.yaml` and model `{project.model_dir}/best_model.zip`.
- Override paths with query params: `config` and `model`.

Examples (PowerShell):

```powershell
curl "http://localhost:8000/rl/predict?ticker=AAPL"
curl "http://localhost:8000/rl/predict?config=configs/aapl_finetune_2025_ext_override_v3_best_no_force.yaml"
``` 

Note: ensure the model checkpoint exists locally (e.g., `models/aapl_finetune_2025_ext/best_model.zip`).

## GOOG tuning sweep + apply best

1) Chạy Optuna sweep cho GOOG (SQLite storage + study name cố định):
   ```powershell
   E:\DACN\.venv\Scripts\python.exe scripts\sweep_goog.py
   ```
   - Kết quả: `reports/optuna/goog.db` và `reports/optuna/goog_best_params.json`

2) Áp dụng best params vào config GOOG mới:
   ```powershell
   E:\DACN\.venv\Scripts\python.exe scripts\apply_optuna_best_generic.py `
     --base-config configs\goog.yaml `
     --best-json reports\optuna\goog_best_params.json `
     --output-config configs\goog_best_from_optuna.yaml
   ```
   - Sau đó có thể train/evaluate forward, walk-forward với `configs\goog_best_from_optuna.yaml`.

3) Watcher generic cho NVDA/AAPL/GOOG (tự apply khi có best mới, tùy chọn auto-train):
    ```powershell
    # Ví dụ NVDA
    E:\DACN\.venv\Scripts\python.exe scripts\watch_optuna_best_generic.py `
       --best-json reports\optuna\nvda_best_params.json `
       --base-config configs\nvda.yaml `
       --output-config configs\nvda_best_from_optuna.yaml `
       --regen-config --threshold 1.8 --auto-train

    # Ví dụ AAPL (nếu dùng file best theo tên mới)
    E:\DACN\.venv\Scripts\python.exe scripts\watch_optuna_best_generic.py `
       --best-json reports\optuna\aapl_best_params.json `
       --base-config configs\aapl.yaml `
       --output-config configs\aapl_best_from_optuna.yaml `
       --regen-config --threshold 1.8 --auto-train
    ```

## Smoke tests (offline, synthetic data)

Chạy bộ smoke tests nhanh để đảm bảo pipeline cốt lõi không vỡ:
```powershell
E:\DACN\.venv\Scripts\python.exe -m unittest discover -s tests -p "test_*.py" -v
```
Bao gồm:
- Loader: shapes/tên features + roundtrip MarketDataset
- Env: reset/step và các info cơ bản
- Backtest: chạy nhanh với model dummy, xác nhận metrics cốt lõi

## Reporting Artifacts

- Per-asset evaluation reviews live under `reports/figures/<ticker>/evaluation_review.md`; GOOG now includes a baseline table contrasting fine-tunes, the optimizer-reset policy (default), and buy-and-hold (`reports/figures/goog/baseline_comparison.md`).
- JSON metrics for each slice/backtest are stored alongside plots (e.g., `reports/figures/goog/evaluation_metrics_post2022_penalty070.json` and `reports/figures/goog/ppo_backtest_post2022_penalty070.png`).
- Forward-paper, walk-forward, and scenario results persist under `reports/forward_paper/`, `reports/walkforward/`, and `reports/scenarios/`.
- Consolidated forward-testing commentary (forward-paper runs, walk-forward stats, scenario outcomes) is tracked in `reports/figures/goog/forward_testing.md` for dashboards/chat gating.
- Run `scripts/update_chat_gating.py` to refresh `reports/chat_gating/status.json`, which summarizes deployment readiness checks across GOOG, AAPL, and NVDA.

## Requirements

- Python 3.12+
 - Gymnasium-compatible environment (custom `TradingEnv` lives under `src/env/trading_env.py`)
- Stable-Baselines3 with PPO
- Torch (CUDA optional)

## Notes

- The data loader enriches market bars with rolling indicators and a logistic regression probability of positive direction.
- The PPO environment enforces an action threshold, probability gate, and trade penalty to curb overtrading.
- Latest long-horizon (500k step) checkpoints and sweep outputs remain in local `models/` and `reports/sweeps/`; commit history excludes the binary artifacts, so publish via LFS or cloud storage if sharing externally.
- Risk governance requirements for any advisory chat deployment are documented in `docs/chat_workflow.md`.

## Streamlit Chat UI (optional)

A minimal chat-style UI is available to query PPO RL signals and market snapshots.

1) Start the API server (in a separate terminal):
   ```powershell
   E:\DACN\.venv\Scripts\python.exe scripts\run_api.py
   ```

2) Launch the Streamlit app:
   ```powershell
   E:\DACN\.venv\Scripts\python.exe -m streamlit run app\streamlit_chat.py
   ```

Notes:
- Default PPO config is `configs/aapl_finetune_2025_ext_override_v3_best_no_force.yaml`. You can override both config and model path in the sidebar.
- Ensure the model checkpoint exists locally (e.g., `models/aapl_finetune_2025_ext/best_model.zip`).
- The Market snapshot shows daily logistic signal context; PPO comes from `/rl/predict`.
