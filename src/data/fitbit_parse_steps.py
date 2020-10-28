import json
import pandas as pd
import numpy as np
from datetime import datetime, timezone
from math import trunc

STEPS_SUMMARY_COLUMNS = ("device_id",
                            "steps_rapids_intradaycountallsteps",
                            "local_date_time",
                            "timestamp")

STEPS_INTRADAY_COLUMNS = ("device_id",
                            "steps",
                            "local_date_time",
                            "timestamp")


def parseStepsData(steps_data):
    if steps_data.empty:
        return pd.DataFrame(), pd.DataFrame(columns=STEPS_INTRADAY_COLUMNS)
    device_id = steps_data["device_id"].iloc[0]
    records_summary, records_intraday = [], []
    # Parse JSON into individual records
    for record in steps_data.fitbit_data:
        record = json.loads(record)  # Parse text into JSON

        # Parse summary data
        curr_date = datetime.strptime(
            record["activities-steps"][0]["dateTime"], "%Y-%m-%d")
        
        row_summary = (device_id,
            record["activities-steps"][0]["value"],
            curr_date,
            0)
        
        records_summary.append(row_summary)

        # Parse intraday data
        dataset = record["activities-steps-intraday"]["dataset"]
        for data in dataset:
            d_time = datetime.strptime(data["time"], '%H:%M:%S').time()
            d_datetime = datetime.combine(curr_date, d_time)

            row_intraday = (device_id,
                data["value"],
                d_datetime,
                0)

            records_intraday.append(row_intraday)

    return pd.DataFrame(data=records_summary, columns=STEPS_SUMMARY_COLUMNS), pd.DataFrame(data=records_intraday, columns=STEPS_INTRADAY_COLUMNS)

table_format = snakemake.params["table_format"]
timezone = snakemake.params["timezone"]

if table_format == "JSON":
    json_raw = pd.read_csv(snakemake.input[0])
    summary, intraday = parseStepsData(json_raw)
elif table_format == "CSV":
    summary = pd.read_csv(snakemake.input[0], parse_dates=["local_date_time"], date_parser=lambda col: pd.to_datetime(col).tz_localize(None))
    intraday = pd.read_csv(snakemake.input[1], parse_dates=["local_date_time"], date_parser=lambda col: pd.to_datetime(col).tz_localize(None))

if summary.shape[0] > 0:
    summary["timestamp"] = summary["local_date_time"].dt.tz_localize(timezone).astype(np.int64) // 10**6
if intraday.shape[0] > 0:
    intraday["timestamp"] = intraday["local_date_time"].dt.tz_localize(timezone).astype(np.int64) // 10**6

summary.to_csv(snakemake.output["summary_data"], index=False)
intraday.to_csv(snakemake.output["intraday_data"], index=False)