from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.hero.service import HeroService
from src.modules.hero.repository import HeroRepository
from src.core.db import get_session


def get_repo(session: AsyncSession = Depends(get_session)):
    return HeroRepository(session)


def get_service(repo: HeroRepository = Depends(get_repo)):
    return HeroService(repo)
