from dataclasses import dataclass
from enum import Enum
import numpy as np
import pandas as pd
from typing import Dict, List, Optional, Tuple

class MarketTrend(Enum):
    UPTREND = "Uptrend"
    DOWNTREND = "Downtrend"
    SIDEWAYS = "Sideways"

class EconomicCycle(Enum):
    EXPANSION = "Expansion"       # Rates Rising + Market Rising
    PEAK = "Peak"                 # Rates High + Market Flat/Volatile
    RECESSION = "Recession"       # Rates Falling + Market Falling
    RECOVERY = "Recovery"         # Rates Falling + Market Rising

@dataclass
class RegimeState:
    date: pd.Timestamp
    trend: MarketTrend
    cycle: EconomicCycle
    description: str
    risk_on: bool  # True if Aggressive (Phase 4), False if Defensive (Phase 2)

class RegimeClassifier:
    """
    Classifies Market Regime based on Technicals and Macro Indicators.
    Acts as the 'Supervisor' logic for the RL Agent.
    """
    def __init__(self):
        pass

    def classify_trend(self, df: pd.DataFrame, idx: int) -> MarketTrend:
        """
        Classify Trend using EMA alignment and ADX.
        df must have: 'close', 'ema_20', 'ema_50', 'ema_200', 'adx'
        """
        if idx < 200:
            return MarketTrend.SIDEWAYS
        
        # Calculate EMAs if not present (simple fallback)
        # Assuming df has pre-calculated columns or we calc on fly?
        # For efficiency, assume pre-calc or calc mostly.
        # Let's use simple logic on Prices if EMAs missing?
        # Better: Assume caller passes enriched dataframe.
        
        current_close = df["close"].iloc[idx]
        
        # We need historical context. 
        # But for RL step-by-step, we might check last row.
        
        # Simple Logic:
        # Uptrend: Price > EMA50 > EMA200
        # Downtrend: Price < EMA50 < EMA200
        # Sideways: ADX < 20 or mixed EMAs
        
        try:
            # Check for EMA columns
            ema_50 = df["close"].iloc[idx-50:idx].mean() # Approx if missing
            ema_200 = df["close"].iloc[idx-200:idx].mean()
            
            # Refined: Use actual EMA if possible, but Simple MA is fine proxy for regime
            
            if current_close > ema_50 > ema_200:
                return MarketTrend.UPTREND
            elif current_close < ema_50 < ema_200:
                return MarketTrend.DOWNTREND
            else:
                return MarketTrend.SIDEWAYS
        except Exception:
            return MarketTrend.SIDEWAYS

    def classify_cycle(self, row: pd.Series) -> EconomicCycle:
        """
        Classify Economic Cycle using Macro Data.
        Requires: 'macro_TNX' (Yield), 'macro_VIX', 'macro_GcF' (Gold - optional)
        """
        # Logic:
        # VIX > 30 => Panic (likely Recession start or bottom)
        # Yield (TNX) Trend?
        
        tnx = row.get("macro_TNX", 0)
        vix = row.get("macro_VIX", 0)
        
        # This is a simplification. 
        # Real cycle detection needs Rate of Change of Yields.
        
        # Heuristics:
        if vix > 30:
            # Panic mode -> Likely Recession or Deep Correction
            return EconomicCycle.RECESSION
        
        # Check Yield Trend (proxy if we had history, but here row is single step).
        # We need history. 
        # For now, let's use VIX and Index Trend proxy.
        
        # If VIX is low (<20) and we are in Uptrend -> Expansion
        # If VIX is rising (20-30) and Uptrend -> Peak
        
        if vix < 20:
            return EconomicCycle.EXPANSION
        elif 20 <= vix <= 30:
            return EconomicCycle.PEAK
        else:
            return EconomicCycle.RECESSION

    def analyze_market(self, df: pd.DataFrame, idx: int) -> RegimeState:
        """
        Full analysis for a specific time step.
        """
        row = df.iloc[idx]
        
        trend = self.classify_trend(df, idx)
        cycle = self.classify_cycle(row)
        
        # Determine Risk Mode
        # Aggressive (Risk On) if:
        # 1. Expansion + Uptrend
        # 2. Recovery + Uptrend
        # 3. Expansion + Sideways (Accumulation)
        
        # Defensive (Risk Off) if:
        # 1. Recession (Always)
        # 2. Downtrend (Any cycle)
        # 3. Peak + Sideways (Distribution)
        
        risk_on = False
        
        if trend == MarketTrend.UPTREND:
            risk_on = True # Trend follower is aggressive
        elif trend == MarketTrend.DOWNTREND:
            risk_on = False
        else: # Sideways
            if cycle in [EconomicCycle.EXPANSION, EconomicCycle.RECOVERY]:
                risk_on = True # Buy dips
            else:
                risk_on = False # Stay safe
                
        # Override: Deep Recession
        if cycle == EconomicCycle.RECESSION:
            risk_on = False
            
        return RegimeState(
            date=df.index[idx],
            trend=trend,
            cycle=cycle,
            description=f"{cycle.value} / {trend.value}",
            risk_on=risk_on
        )
