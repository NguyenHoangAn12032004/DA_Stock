"""Helper entry point to launch the FastAPI advice server."""
from __future__ import annotations

import sys
from pathlib import Path

import uvicorn
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))


def main() -> None:
    load_dotenv()
    uvicorn.run(
        "src.api.advice_server:app",
        host="0.0.0.0",
        port=8001,
        reload=False,
        workers=1,
    )


if __name__ == "__main__":
    sys.exit(main())
