# criar_projeto_mt4.ps1

$Base = "$HOME\Desktop\MT4_Backtester"

New-Item -ItemType Directory -Force -Path $Base | Out-Null

$Pastas = @(
    "experts",
    "reports",
    "configs",
    "presets",
    "results",
    "logs"
)

foreach($p in $Pastas){
    New-Item -ItemType Directory -Force -Path "$Base\$p" | Out-Null
}

# config.py
@'
from pathlib import Path

BASE_DIR = Path(__file__).parent

EXPERTS_DIR = BASE_DIR / "experts"
REPORTS_DIR = BASE_DIR / "reports"
CONFIGS_DIR = BASE_DIR / "configs"
PRESETS_DIR = BASE_DIR / "presets"
RESULTS_DIR = BASE_DIR / "results"
LOGS_DIR = BASE_DIR / "logs"

DEFAULT_SYMBOL = "EURUSD"
DEFAULT_PERIOD = 60
DEFAULT_DEPOSIT = 10000

MT4_PATH = ""
METAEDITOR_PATH = ""
'@ | Set-Content "$Base\config.py"

# mt4_scanner.py
@'
from pathlib import Path

def find_mt4_terminals():
    roots = [
        Path("C:/Program Files"),
        Path("C:/Program Files (x86)"),
        Path.home() / "AppData/Roaming/MetaQuotes/Terminal"
    ]

    found = []

    for root in roots:
        if root.exists():
            for exe in root.rglob("terminal.exe"):
                found.append(str(exe))

    return found
'@ | Set-Content "$Base\mt4_scanner.py"

# compiler.py
@'
import subprocess

def compile_mq4(metaeditor, mq4_file):

    cmd = [
        metaeditor,
        f"/compile:{mq4_file}"
    ]

    subprocess.run(cmd)
'@ | Set-Content "$Base\compiler.py"

# backtest_runner.py
@'
import os
import subprocess
import time

def create_ini(
    path,
    expert,
    symbol,
    period,
    deposit,
    report
):

    content = f"""
[Tester]
Expert={expert}
Symbol={symbol}
Period={period}
Model=0
FromDate=2020.01.01
ToDate=2025.01.01
Deposit={deposit}
Currency=USD
Report={report}
ReplaceReport=1
ShutdownTerminal=1
"""

    with open(path, "w") as f:
        f.write(content)

def run_backtest(
    terminal,
    ini_file,
    report_file,
    timeout=600
):

    subprocess.Popen([
        terminal,
        f"/config:{os.path.abspath(ini_file)}"
    ])

    start = time.time()

    while True:

        if os.path.exists(report_file):
            return True

        if time.time() - start > timeout:
            return False

        time.sleep(3)
'@ | Set-Content "$Base\backtest_runner.py"

# optimizer.py
@'
def create_optimization_ini(
    path,
    expert,
    setfile
):

    txt = f"""
[Tester]
Expert={expert}
Optimization=1
ExpertParameters={setfile}
ReplaceReport=1
"""

    with open(path, "w") as f:
        f.write(txt)
'@ | Set-Content "$Base\optimizer.py"

# report_parser.py
@'
import re

def parse_report(file_path):

    with open(
        file_path,
        encoding="utf-16",
        errors="ignore"
    ) as f:

        html = f.read()

    result = {
        "profit": 0,
        "profit_factor": 0,
        "drawdown": 0
    }

    p = re.search(
        r"Total Net Profit.*?(-?\d+\.?\d*)",
        html
    )

    if p:
        result["profit"] = float(
            p.group(1)
        )

    pf = re.search(
        r"Profit Factor.*?(\d+\.?\d*)",
        html
    )

    if pf:
        result["profit_factor"] = float(
            pf.group(1)
        )

    dd = re.search(
        r"Relative Drawdown.*?(\d+\.?\d*)",
        html
    )

    if dd:
        result["drawdown"] = float(
            dd.group(1)
        )

    return result
'@ | Set-Content "$Base\report_parser.py"

# database.py
@'
import sqlite3

DB = "results/results.db"

def create():

    conn = sqlite3.connect(DB)

    conn.execute("""
    CREATE TABLE IF NOT EXISTS results(
        id INTEGER PRIMARY KEY,
        expert TEXT,
        profit REAL,
        profit_factor REAL,
        drawdown REAL
    )
    """)

    conn.commit()
    conn.close()

def save(
    expert,
    profit,
    factor,
    drawdown
):

    conn = sqlite3.connect(DB)

    conn.execute("""
    INSERT INTO results(
        expert,
        profit,
        profit_factor,
        drawdown
    )
    VALUES(?,?,?,?)
    """,(
        expert,
        profit,
        factor,
        drawdown
    ))

    conn.commit()
    conn.close()
'@ | Set-Content "$Base\database.py"

# ranking.py
@'
import pandas as pd
import sqlite3

def export():

    conn = sqlite3.connect(
        "results/results.db"
    )

    df = pd.read_sql(
        "SELECT * FROM results",
        conn
    )

    df = df.sort_values(
        [
            "profit_factor",
            "profit"
        ],
        ascending=False
    )

    df.to_csv(
        "results/ranking.csv",
        index=False
    )

    print(df.head(20))
'@ | Set-Content "$Base\ranking.py"

# app.py
@'
from config import *
from mt4_scanner import *
from backtest_runner import *
from report_parser import *
from database import *
from ranking import *

create()

terminals = find_mt4_terminals()

if not terminals:
    raise Exception("MT4 não encontrado")

terminal = terminals[0]

print("MT4 encontrado:", terminal)

for file in EXPERTS_DIR.iterdir():

    if file.suffix.lower() not in [".mq4",".ex4"]:
        continue

    expert_name = file.stem

    ini = CONFIGS_DIR / (expert_name + ".ini")
    report = REPORTS_DIR / (expert_name + ".htm")

    create_ini(
        str(ini),
        expert_name,
        DEFAULT_SYMBOL,
        DEFAULT_PERIOD,
        DEFAULT_DEPOSIT,
        expert_name
    )

    ok = run_backtest(
        terminal,
        str(ini),
        str(report)
    )

    if not ok:
        continue

    data = parse_report(str(report))

    save(
        expert_name,
        data["profit"],
        data["profit_factor"],
        data["drawdown"]
    )

export()
'@ | Set-Content "$Base\app.py"

@'
pandas
beautifulsoup4
lxml
'@ | Set-Content "$Base\requirements.txt"

Write-Host ""
Write-Host "Projeto criado em:"
Write-Host $Base
Write-Host ""