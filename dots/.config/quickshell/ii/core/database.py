"""
database.py — SiM SQLite async database setup.
"""

import logging
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import declarative_base, sessionmaker
from config import DATABASE_URL

logger = logging.getLogger("sim.db")

# Convert sqlite:// → sqlite+aiosqlite://
_async_url = DATABASE_URL.replace("sqlite:///", "sqlite+aiosqlite:///")

async_engine = create_async_engine(_async_url, echo=False)
AsyncSessionLocal = sessionmaker(async_engine, class_=AsyncSession, expire_on_commit=False)
Base = declarative_base()


async def init_db():
    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("SiM database initialized.")


async def close_db():
    await async_engine.dispose()
