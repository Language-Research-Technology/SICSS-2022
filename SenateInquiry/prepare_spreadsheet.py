"""
Takes the folder of raw text files and transforms them into a tidy CSV, with
one row per *submission*. Note that a submission consists of the main
submission document as a pdf, along with a 0 or more attachments. For the
purposes of this analysis, we will focus on the submission alone, and discard
the attachments.

A series of regular expressions is used to filter out some low-content parts
of the text (salutations, greetings, corporate boilerplate etc.)

"""

import argparse
import csv
import glob
import io
import os
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument("source_folder")
parser.add_argument("source_csv")
parser.add_argument("target_csv")

args = parser.parse_args()

# Exclude lines if they match any of the following regular expressions.
# TODO - this could be read from a separate file and be used as an input
# argument.
exclude_expressions = [
    re.compile(expression)
    for expression in [
        r"^\f*Regional Inequality in Australia$",
        r"^Submission \d+",
        r"Fitt",
        r"Ketter",
        r"^Chair",
        r"@",
        r"Sir",
        r"ABN",
        r"^Enquiries",
        r"^Telephone",
        r"^Our Ref:",
        r"^Your Ref:",
        r"\d{1,2}\w{0,2} [A-Z]\w+ \d{4}",
        r"^Parliament House",
        r"^Senate Economics References Committee",
        r"^Senate Standing Committees? on Economics",
        r"Committee Secretary",
        r"Department of the Senate",
        r"PO Box",
        r"^www",
        r"ACT",
    ]
]


contains_nulls = []


with open(args.target_csv, "w", encoding="utf8") as f_out, open(
    args.source_csv, "r"
) as source_f:

    reader = csv.DictReader(source_f)

    fieldnames = [
        "Filename",
        "Submission",
        "Source",
        "Size",
        "Category",
        "Filetype",
        "Text",
    ]

    writer = csv.DictWriter(f_out, fieldnames, quoting=csv.QUOTE_ALL)
    writer.writeheader()

    for row in reader:

        # Use empty string as a marker for a missing file.
        if row["Filename"]:
            file = os.path.join(args.source_folder, row["Filename"])

            with open(file, "r", encoding="utf8", errors="ignore") as f_in:

                included_lines = []
                excluded_lines = 0

                for line in f_in:

                    # If it matches any of the included expressions, discard the
                    # line.
                    for exp in exclude_expressions:
                        if exp.search(line):
                            excluded_lines += 1
                            break
                    # None of the exclusions matched, keep the line.
                    else:
                        included_lines.append(line)

                print(
                    f"Processed file '{file}' with {len(included_lines)} lines included and {excluded_lines} lines excluded."
                )

                # Some of the OCR/PDF extraction results in a lot of null bytes,
                # Ideally we'd fix that up earlier in the pipeline...
                included_text = "".join(included_lines).replace("\00", "")

                row["Text"] = included_text

        writer.writerow(row)
