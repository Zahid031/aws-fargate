from pydantic import BaseModel, ConfigDict


class HeroCreate(BaseModel):
    name: str
    age: int | None = None
    secret_name: str


class HeroRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    age: int | None
    secret_name: str
