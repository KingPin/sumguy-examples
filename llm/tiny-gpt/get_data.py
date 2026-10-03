"""Download the training corpus for the tiny-gpt series.

Nine public-domain Sherlock Holmes books from Project Gutenberg, with the
Gutenberg license header and footer stripped. Writes data/holmes.txt
(about 4 MB) next to this script. Every part of the series reads that file.
"""

import pathlib
import urllib.request

BOOKS = {
    244: "A Study in Scarlet",
    2097: "The Sign of the Four",
    1661: "The Adventures of Sherlock Holmes",
    834: "The Memoirs of Sherlock Holmes",
    2852: "The Hound of the Baskervilles",
    108: "The Return of Sherlock Holmes",
    3289: "The Valley of Fear",
    2350: "His Last Bow",
    69700: "The Case-Book of Sherlock Holmes",
}

OUT = pathlib.Path(__file__).parent / "data" / "holmes.txt"


def strip_gutenberg(text: str) -> str:
    # Keep only what sits between the "*** START OF ..." and "*** END OF ..." markers.
    start = text.index("*** START OF")
    start = text.index("\n", start) + 1
    end = text.index("*** END OF")
    return text[start:end].strip()


def main() -> None:
    OUT.parent.mkdir(exist_ok=True)
    parts = []
    for book_id, title in BOOKS.items():
        url = f"https://www.gutenberg.org/cache/epub/{book_id}/pg{book_id}.txt"
        raw = urllib.request.urlopen(url).read().decode("utf-8-sig")
        body = strip_gutenberg(raw).replace("\r\n", "\n")
        print(f"{title:<36} {len(body):>9,} chars")
        parts.append(body)
    text = "\n\n".join(parts)
    OUT.write_text(text, encoding="utf-8")
    print(f"\nwrote {OUT} ({len(text):,} chars, {OUT.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
