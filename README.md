# Devops Assessment

## How to Run

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
git clone https://github.com/goldkinen/devops-assessment.git
cd devops-assessment
uv venv --python 3.13
source .venv/bin/activate
uv sync

export PYTHONPATH=$(pwd)
export $(xargs < .env)
uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload
```
