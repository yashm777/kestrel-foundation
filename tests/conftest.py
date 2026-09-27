import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

import pytest

DATA = ROOT / "data"
DB = ROOT / "warehouse" / "kestrel.duckdb"


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return ROOT


@pytest.fixture(scope="session")
def data_dir() -> Path:
    if not (DATA / "raw").exists():
        pytest.skip("data/raw not generated")
    return DATA


@pytest.fixture(scope="session")
def db_path() -> Path:
    if not DB.exists():
        pytest.skip("warehouse/kestrel.duckdb not built")
    return DB
