import os
import time
from datetime import datetime, date, timedelta, timezone
import requests
from dotenv import load_dotenv
import csv

load_dotenv()
API_KEY = os.getenv("MASSIVE_API_KEY")
BASE_URL = "https://api.massive.com"
SLEEP_TIME = 10

def get_stock_prices(req_date):
    try:
        url = f"{BASE_URL}/v2/aggs/grouped/locale/us/market/stocks/{req_date}"
        params = {
            "adjusted": "true",
            "include_otc": "false",
            "apiKey": API_KEY,
        }
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        return data.get("results")
    except Exception as e:
        print(e)
        return None

def load_historical_data_to_csv(historical_data, start_date, end_date):
    out_file = (
        f"massive_eod_grouped_"
        f"{start_date.strftime('%Y%m%d')}_"
        f"{end_date.strftime('%Y%m%d')}.csv"
    )

    # Static metadata for all rows in this file
    ingest_ts = (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
    )
    with open(out_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["trade_date", "symbol", "open", "high", "low", "close", "volume", "_src_file", "_ingest_ts"])

        for row in historical_data:
            writer.writerow([
                row["trade_date"],
                row["symbol"],
                row["open"],
                row["high"],
                row["low"],
                row["close"],
                row["volume"],
                out_file,
                ingest_ts
            ])
    print(f"\nCSV created successfully: {out_file}")

    return out_file



def extract_historical_data(start_date, end_date):

    curr_dt = start_date
    historical_data = []
    while curr_dt <= end_date:
        print(f"Fetching data for {curr_dt}...")
        stock_prices = get_stock_prices(curr_dt)
        if stock_prices:
            print(f"{curr_dt}: {len(stock_prices)} records")
            for row in stock_prices:
                historical_data.append({
                    "trade_date": curr_dt,
                    "symbol": row.get("T", ""),
                    "open": row.get("o", ""),
                    "high": row.get("h", ""),
                    "low": row.get("l", ""),
                    "close": row.get("c", ""),
                    "volume": row.get("v", "")
                })
        else:
            print(
                f"No results for {curr_dt}. "
                "It may be a weekend or holiday."
            )
        curr_dt += timedelta(days=1)
        time.sleep(SLEEP_TIME)
    print(
        f"\nExtraction completed. "
        f"Total records: {len(historical_data)}"
    )

    return historical_data

def main():

    start_date = date(2026, 8, 1)
    end_date = date(2026, 8, 7)

    historical_data = extract_historical_data(start_date, end_date)

    output_file = load_historical_data_to_csv(historical_data, start_date, end_date)

    print(f"Output file: {output_file}")


if __name__ == "__main__":
    main()