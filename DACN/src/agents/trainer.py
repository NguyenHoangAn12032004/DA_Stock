from __future__ import annotations

from pathlib import Path
from typing import Any, Callable, Dict, Optional, Tuple

import numpy as np
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import BaseCallback, CallbackList, EvalCallback
from stable_baselines3.common.monitor import Monitor
from stable_baselines3.common.vec_env import DummyVecEnv

from src.env.trading_env import EnvConfig, TradingEnv


class HyperparamScheduleCallback(BaseCallback):
    def __init__(
        self,
        total_timesteps: int,
        lr_schedule: Callable[[float], float] | None = None,
        ent_coef_schedule: Callable[[float], float] | None = None,
    ) -> None:
        super().__init__()
        self.total_timesteps = max(total_timesteps, 1)
        self.lr_schedule = lr_schedule
        self.ent_coef_schedule = ent_coef_schedule
        self._start_timesteps = 0

    def _on_training_start(self) -> None:
        self._start_timesteps = self.model.num_timesteps

    def _on_step(self) -> bool:
        elapsed = self.model.num_timesteps - self._start_timesteps
        progress = min(max(elapsed / self.total_timesteps, 0.0), 1.0)
        if self.lr_schedule:
            current_lr = self.lr_schedule(progress)
            self.model.learning_rate = current_lr
            for group in self.model.policy.optimizer.param_groups:
                group["lr"] = current_lr
        if self.ent_coef_schedule:
            current_ent = self.ent_coef_schedule(progress)
            self.model.ent_coef = current_ent
        return True


def make_env(dataset: Dict[str, np.ndarray], config: EnvConfig, seed: int, n_envs: int = 1) -> Any:
    def _make_single(rank):
        def _init():
            # CRITICAL: Pin worker threads to 1 on Windows to prevent oversubscription
            # This allows the Main Learner process to use the remaining cores
            import os
            import torch
            os.environ["OMP_NUM_THREADS"] = "1"
            os.environ["MKL_NUM_THREADS"] = "1"
            torch.set_num_threads(1)
            
            env = TradingEnv(dataset, config)
            env = Monitor(env)
            env.reset(seed=seed + rank)
            return env
        return _init

    if n_envs > 1:
        print(f"DEBUG: Attempting to create SubprocVecEnv with {n_envs} environments...")
        # Check if SubprocVecEnv is available (linux/macos/windows with limitations)
        try:
             from stable_baselines3.common.vec_env import SubprocVecEnv
             vec_env = SubprocVecEnv([_make_single(i) for i in range(n_envs)])
             print("DEBUG: SubprocVecEnv created successfully.")
             return vec_env
        except ImportError:
             print("DEBUG: SubprocVecEnv not found, falling back to DummyVecEnv")
             return DummyVecEnv([_make_single(0)])
        except Exception as e:
             print(f"DEBUG: Error creating SubprocVecEnv: {e}")
             return DummyVecEnv([_make_single(0)])
    else:
        print("DEBUG: Creating Single DummyVecEnv (n_envs=1)")
        return DummyVecEnv([_make_single(0)])


try:
    from sb3_contrib import RecurrentPPO
except ImportError:
    RecurrentPPO = None

def train_ppo_agent(
    dataset: Dict[str, np.ndarray],
    train_config: EnvConfig,
    eval_config: EnvConfig,
    model_path: Path,
    log_dir: Path,
    total_timesteps: int = 300_000,
    chunk_size: Optional[int] = None,
    resume: bool = False,
    reset_optimizer: bool = False,
    learning_rate: float = 3e-4,
    gamma: float = 0.99,
    gae_lambda: float = 0.95,
    clip_range: float = 0.2,
    n_steps: int = 2048,
    batch_size: int = 256,
    ent_coef: float = 0.01,
    vf_coef: float = 0.5,
    max_grad_norm: float = 0.5,
    policy_kwargs: Dict | None = None,
    seed: int = 42,
    eval_freq: int | None = None,
    lr_schedule: Callable[[float], float] | None = None,
    ent_coef_schedule: Callable[[float], float] | None = None,
    algorithm_class: Any = PPO,
    n_envs: int = 1,
) -> Tuple[Any, Dict[str, float]]:
    log_dir.mkdir(parents=True, exist_ok=True)
    model_path.parent.mkdir(parents=True, exist_ok=True)

    train_env = make_env(dataset, train_config, seed, n_envs=n_envs)
    # MATCH ENV TYPE: Use same n_envs (or at least same VecEnv class) for Eval to avoid Windows pickling/deadlock issues
    # If train is Subproc, make Eval Subproc too.
    eval_env_n_envs = n_envs if n_envs > 1 else 1
    eval_env = make_env(dataset, eval_config, seed + 1, n_envs=eval_env_n_envs)

    chunk_size = max(chunk_size or total_timesteps, 1)

    if resume and model_path.exists():
        loaded_model = algorithm_class.load(model_path, env=train_env, tensorboard_log=str(log_dir))
        if reset_optimizer:
            current_lr = learning_rate
            if loaded_model.policy.optimizer is not None and loaded_model.policy.optimizer.param_groups:
                current_lr = loaded_model.policy.optimizer.param_groups[0].get("lr", learning_rate)

            current_ent = getattr(loaded_model, "ent_coef", ent_coef)
            parameters = loaded_model.get_parameters()
            prev_timesteps = loaded_model.num_timesteps
            prev_total_timesteps = getattr(loaded_model, "_total_timesteps", prev_timesteps)
            prev_updates = getattr(loaded_model, "_n_updates", 0)

            model = algorithm_class(
                "MlpLstmPolicy" if algorithm_class == RecurrentPPO else "MlpPolicy",
                train_env,
                learning_rate=learning_rate,
                n_steps=n_steps,
                batch_size=batch_size,
                gamma=gamma,
                gae_lambda=gae_lambda,
                clip_range=clip_range,
                ent_coef=ent_coef,
                vf_coef=vf_coef,
                max_grad_norm=max_grad_norm,
                tensorboard_log=str(log_dir),
                policy_kwargs=policy_kwargs or {},
                seed=seed,
                verbose=1,
            )
            model.set_parameters(parameters, exact_match=True)
            model.num_timesteps = prev_timesteps
            model._total_timesteps = prev_total_timesteps
            model._n_updates = prev_updates
            model.learning_rate = current_lr
            model.ent_coef = current_ent

            optimizer = model.policy.optimizer
            if optimizer is not None:
                optimizer.defaults["lr"] = current_lr
                for group in optimizer.param_groups:
                    group["lr"] = current_lr
        else:
            model = loaded_model
            model.set_env(train_env)
        del loaded_model
    else:
        policy_name = "MlpLstmPolicy" if algorithm_class == RecurrentPPO else "MlpPolicy"
        # Allow override from policy_kwargs or config if passed differently, but default to correct one
        if policy_kwargs and "policy" in policy_kwargs:
             policy_name = policy_kwargs.pop("policy")
        
        model = algorithm_class(
            policy_name,
            train_env,
            learning_rate=learning_rate,
            n_steps=n_steps,
            batch_size=batch_size,
            gamma=gamma,
            gae_lambda=gae_lambda,
            clip_range=clip_range,
            ent_coef=ent_coef,
            vf_coef=vf_coef,
            max_grad_norm=max_grad_norm,
            tensorboard_log=str(log_dir),
            policy_kwargs=policy_kwargs or {},
            seed=seed,
            verbose=1,
            device="auto" # Auto-detect CUDA/CPU
        )

    trained_steps = 0
    remaining = total_timesteps

    schedule_callback = None
    if lr_schedule or ent_coef_schedule:
        schedule_callback = HyperparamScheduleCallback(total_timesteps, lr_schedule, ent_coef_schedule)

    while remaining > 0:
        current_chunk = min(chunk_size, remaining)
        callbacks: list[BaseCallback] = []
        if eval_freq:
            callbacks.append(
                EvalCallback(
                    eval_env,
                    best_model_save_path=str(model_path.parent),
                    log_path=str(log_dir),
                    eval_freq=eval_freq,
                    deterministic=True,
                    render=False,
                )
            )
        if schedule_callback:
            callbacks.append(schedule_callback)
        callback: BaseCallback | CallbackList | None = None
        if callbacks:
            callback = callbacks[0] if len(callbacks) == 1 else CallbackList(callbacks)

        model.learn(
            total_timesteps=current_chunk,
            callback=callback,
            reset_num_timesteps=(trained_steps == 0 and not resume),
        )

        trained_steps += current_chunk
        remaining -= current_chunk
        model.save(model_path)

    train_env.close()
    eval_env.close()

    info = {
        "timesteps": trained_steps,
        "model_path": str(model_path),
    }
    return model, info
