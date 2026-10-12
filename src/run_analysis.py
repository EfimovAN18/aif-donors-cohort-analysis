"""
Воспроизводит анализ локально: выполняет SQL-запросы из папки sql/,
сохраняет результаты в CSV, строит графики и короткую сводку.

Запуск:
    pip install -r requirements.txt
    cp .env.example .env   # и впишите пароль
    python src/run_analysis.py
"""

from __future__ import annotations

import os
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / "sql"
RESULTS_DIR = ROOT / "data" / "results"
FIGURES_DIR = ROOT / "reports" / "figures"

COLORS = {"female": "#d62728", "male": "#1f77b4"}  # женщины — красный, мужчины — синий


def get_engine():
    load_dotenv(ROOT / ".env")
    url = URL.create(
        "postgresql+psycopg2",
        username=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", 6432)),
        database=os.environ["DB_NAME"],
    )
    return create_engine(url, connect_args={"sslmode": os.environ.get("DB_SSLMODE", "require")})


def run_query(engine, name: str) -> pd.DataFrame:
    query = (SQL_DIR / name).read_text(encoding="utf-8")
    with engine.connect() as conn:
        df = pd.read_sql(text(query), conn)
    df.to_csv(RESULTS_DIR / name.replace(".sql", ".csv"), index=False, encoding="utf-8")
    return df


def sex_color(value: str) -> str:
    v = str(value).lower()
    if v.startswith(("f", "ж")):
        return COLORS["female"]
    if v.startswith(("m", "м")):
        return COLORS["male"]
    return "gray"


def plot_mau(df: pd.DataFrame) -> None:
    fig, ax = plt.subplots(figsize=(12, 5))
    ax.plot(pd.to_datetime(df["Месяц"]), df["MAU"], marker="o", color="#2f4b7c")
    ax.axvline(pd.Timestamp("2022-08-01"), color="gray", ls="--", lw=1)
    ax.text(pd.Timestamp("2022-08-01"), ax.get_ylim()[1] * 0.95, " кампания 08.2022",
            color="gray", va="top")
    ax.set_title("Динамика MAU (благотворители с ≥1 оплаченным пожертвованием)")
    ax.set_ylabel("Активные благотворители")
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(FIGURES_DIR / "01_mau.png", dpi=150)
    plt.close(fig)


def plot_retention(df: pd.DataFrame) -> None:
    fig, ax = plt.subplots(figsize=(10, 5))
    for sex, part in df.groupby("Пол"):
        ax.plot(part["Месяц"], part["Retention Rate"], marker="o",
                label=str(sex), color=sex_color(sex))
    ax.set_title("Retention Rate когорты августа 2022 по полу")
    ax.set_xlabel("Месяцев с августа 2022")
    ax.set_ylabel("Retention Rate")
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda y, _: f"{y:.0%}"))
    ax.legend()
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(FIGURES_DIR / "02_retention_by_sex.png", dpi=150)
    plt.close(fig)


def main() -> None:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)
    engine = get_engine()

    mau = run_query(engine, "01_mau.sql")
    retention = run_query(engine, "02_retention_by_sex.sql")
    avg_check = run_query(engine, "03_avg_check_by_sex.sql")
    ltv = run_query(engine, "04_ltv_by_city.sql")

    plot_mau(mau)
    plot_retention(retention)

    peak = mau.loc[mau["MAU"].idxmax()]
    summary = [
        "# Сводка результатов (сгенерировано src/run_analysis.py)\n",
        f"- Пик MAU: **{int(peak['MAU'])}** в {pd.to_datetime(peak['Месяц']):%m.%Y}",
        f"- Средний MAU за период: **{mau['MAU'].mean():.0f}**\n",
        "## Retention Rate (первые 6 месяцев)\n",
        retention[retention["Месяц"] <= 6].pivot(index="Месяц", columns="Пол",
                                                 values="Retention Rate").to_markdown(),
        "\n## Средний чек по полу\n",
        avg_check.to_markdown(index=False),
        "\n## LTV по городам\n",
        ltv.to_markdown(index=False),
    ]
    (ROOT / "reports" / "summary.md").write_text("\n".join(summary), encoding="utf-8")
    print("Готово: data/results/*.csv, reports/figures/*.png, reports/summary.md")


if __name__ == "__main__":
    main()
