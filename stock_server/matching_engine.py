import time
import heapq
import uuid
import threading
from typing import List, Dict, Optional
from enum import Enum
import dataclasses

# --- Enum Types ---
class OrderSide(str, Enum):
    BUY = "BUY"
    SELL = "SELL"

class OrderType(str, Enum):
    LIMIT = "LIMIT"
    MARKET = "MARKET"

class OrderStatus(str, Enum):
    PENDING = "PENDING"
    PARTIAL = "PARTIAL"
    FILLED = "FILLED"
    CANCELED = "CANCELED"

# --- Data Models ---
@dataclasses.dataclass(order=True)
class Order:
    # Custom sort order for Heap:
    # - Bids: Highest Price first, then Earliest Timestamp
    # - Asks: Lowest Price first, then Earliest Timestamp
    # We'll handle sorting logic in the OrderBook add method, mainly just store data here.
    
    id: str = dataclasses.field(compare=False)
    user_id: str = dataclasses.field(compare=False)
    symbol: str = dataclasses.field(compare=False)
    side: OrderSide = dataclasses.field(compare=False)
    type: OrderType = dataclasses.field(compare=False)
    price: float # Limit Price (MAX for Market Buy, 0 for Market Sell generally, but handled via logic)
    quantity: int = dataclasses.field(compare=False)
    filled_quantity: int = dataclasses.field(default=0, compare=False)
    timestamp: float = dataclasses.field(default_factory=time.time, compare=False)
    status: OrderStatus = dataclasses.field(default=OrderStatus.PENDING, compare=False)

    @property
    def remaining_quantity(self) -> int:
        return self.quantity - self.filled_quantity

    def to_dict(self):
        return dataclasses.asdict(self)

class OrderBook:
    def __init__(self, symbol: str):
        self.symbol = symbol
        # We use lists and sort them. For MVP high-frequency is not needed.
        # Bids: [Order(price=100), Order(price=99)] (Desc)
        self.bids: List[Order] = [] 
        # Asks: [Order(price=101), Order(price=102)] (Asc)
        self.asks: List[Order] = []
        self.lock = threading.Lock()

    def add_order(self, order: Order):
        with self.lock:
            if order.side == OrderSide.BUY:
                self.bids.append(order)
                # Sort Bids: Descending Price, Ascending Time
                self.bids.sort(key=lambda x: (-x.price, x.timestamp))
            else:
                self.asks.append(order)
                # Sort Asks: Ascending Price, Ascending Time
                self.asks.sort(key=lambda x: (x.price, x.timestamp))
    
    def remove_order(self, order_id: str):
        with self.lock:
            self.bids = [o for o in self.bids if o.id != order_id]
            self.asks = [o for o in self.asks if o.id != order_id]

    def match(self) -> List[Dict]:
        """
        Executes matching logic.
        Returns a list of 'Trade' dicts (executed transactions).
        """
        transactions = []
        with self.lock:
            print(f"🔍 Matching Check: {len(self.bids)} Bids, {len(self.asks)} Asks")
            while self.bids and self.asks:
                best_bid = self.bids[0]
                best_ask = self.asks[0]

                print(f"   Compare: Bid({best_bid.price}) vs Ask({best_ask.price})")

                # Check Price Crossing
                # Spread = Ask - Bid. Matching happens if Ask <= Bid.
                if best_ask.price > best_bid.price:
                    # Print explicit reason for user clarity
                    print(f"   -> No Match (Best Bid {best_bid.price} < Best Ask {best_ask.price})")
                    break # No match possible
                
                print(f"✅ MATCH! Bid({best_bid.price}) >= Ask({best_ask.price})")
                
                # MATCH FOUND!
                # Price logic: Transaction happens at the Maker's price (the one who was there first)
                # If Bid came first (Maker), price = Bid. If Ask came first, price = Ask.
                # Simplified: Always match at the price of the order that was ALREADY in the book.
                # However, for simplicity here, we'll match at the price of the LIMIT order being filled if both limit.
                # Standard convention: Match at the price of the 'resting' order (Maker).
                
                # Let's assume we match at the mid-point or simply the best_ask price for simplicity in simulation.
                # Real exchange: Match price = Price of the order that was in the book first.
                match_price = best_ask.price if best_ask.timestamp < best_bid.timestamp else best_bid.price
                
                match_qty = min(best_bid.remaining_quantity, best_ask.remaining_quantity)
                
                # Create Transaction
                trade = {
                    "id": str(uuid.uuid4()),
                    "symbol": self.symbol,
                    "buy_order_id": best_bid.id,
                    "sell_order_id": best_ask.id,
                    "price": match_price,
                    "quantity": match_qty,
                    "timestamp": time.time(),
                    "buyer_id": best_bid.user_id,
                    "seller_id": best_ask.user_id
                }
                transactions.append(trade)
                
                # Update Quantities
                best_bid.filled_quantity += match_qty
                best_ask.filled_quantity += match_qty
                
                # Update Status checking
                if best_bid.remaining_quantity == 0:
                    best_bid.status = OrderStatus.FILLED
                    self.bids.pop(0) # Remove filled
                else:
                    best_bid.status = OrderStatus.PARTIAL
                    
                if best_ask.remaining_quantity == 0:
                    best_ask.status = OrderStatus.FILLED
                    self.asks.pop(0) # Remove filled
                else:
                    best_ask.status = OrderStatus.PARTIAL
                    
        return transactions

    def get_depth(self, limit: int = 10):
        # Return snapshot for UI
        return {
            "bids": [{"price": o.price, "qty": o.remaining_quantity} for o in self.bids[:limit]],
            "asks": [{"price": o.price, "qty": o.remaining_quantity} for o in self.asks[:limit]]
        }

# --- Singleton Engine ---
class MatchingEngine:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(MatchingEngine, cls).__new__(cls)
            cls._instance.books = {} # Dict[str, OrderBook]
            cls._instance.lock = threading.Lock()
        return cls._instance

    def get_book(self, symbol: str) -> OrderBook:
        with self.lock:
            if symbol not in self.books:
                self.books[symbol] = OrderBook(symbol)
            return self.books[symbol]

    def place_order(self, order: Order) -> List[Dict]:
        book = self.get_book(order.symbol)
        book.add_order(order)
        trades = book.match()
        return trades

    def get_orderbook(self, symbol: str):
        return self.get_book(symbol).get_depth()

    def get_best_ask(self, symbol: str) -> float:
        book = self.get_book(symbol)
        with book.lock:
            # Asks are sorted ascending (Lowest Price first)
            if book.asks:
                return book.asks[0].price
            return 0.0

    def get_best_bid(self, symbol: str) -> float:
        book = self.get_book(symbol)
        with book.lock:
            # Bids are sorted descending (Highest Price first)
            if book.bids:
                return book.bids[0].price
            return 0.0

# Global Instance
engine = MatchingEngine()
