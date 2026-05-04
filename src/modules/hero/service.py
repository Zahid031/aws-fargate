from fastapi import HTTPException

from src.modules.hero.repository import HeroRepository
from src.modules.hero.schemas import HeroCreate


class HeroService:
    def __init__(self, repo: HeroRepository):
        self.repo = repo

    async def create(self, data: HeroCreate):
        return await self.repo.create(data)

    async def list(self, offset: int, limit: int):
        return await self.repo.get_all(offset, limit)

    async def get(self, hero_id: int):
        hero = await self.repo.get_by_id(hero_id)
        if not hero:
            raise HTTPException(status_code=404, detail="Hero not found")
        return hero

    async def delete(self, hero_id: int):
        hero = await self.repo.get_by_id(hero_id)
        if not hero:
            raise HTTPException(status_code=404, detail="Hero not found")
        await self.repo.delete(hero)
        return {"ok": True}
