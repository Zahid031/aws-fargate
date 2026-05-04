from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from src.core.db import Base


class Hero(Base):
    __tablename__ = "heroes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(100), index=True)
    age: Mapped[int | None] = mapped_column(Integer, nullable=True)
    secret_name: Mapped[str] = mapped_column(String(100))
