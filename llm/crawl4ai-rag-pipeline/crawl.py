"""Deep-crawl a docs site to fit-markdown files on disk."""
import asyncio
import hashlib
import json
import sys
from pathlib import Path

from crawl4ai import (
    AsyncWebCrawler,
    BFSDeepCrawlStrategy,
    BrowserConfig,
    CacheMode,
    CrawlerRunConfig,
    DefaultMarkdownGenerator,
    PruningContentFilterLXML,
)
from crawl4ai.deep_crawling import DomainFilter, FilterChain, URLPatternFilter

START_URL = sys.argv[1] if len(sys.argv) > 1 else "https://docs.example.com/"
MAX_PAGES = int(sys.argv[2]) if len(sys.argv) > 2 else 50
OUT = Path("pages")


async def main() -> None:
    host = START_URL.split("/")[2]
    config = CrawlerRunConfig(
        deep_crawl_strategy=BFSDeepCrawlStrategy(
            max_depth=2,
            max_pages=MAX_PAGES,
            filter_chain=FilterChain(
                [
                    DomainFilter(allowed_domains=[host]),
                    URLPatternFilter(patterns=["*/changelog/*", "*/blog/*"], reverse=True),
                ]
            ),
        ),
        markdown_generator=DefaultMarkdownGenerator(
            content_filter=PruningContentFilterLXML(threshold=0.48, threshold_type="fixed")
        ),
        cache_mode=CacheMode.ENABLED,  # re-runs hit the local cache, not the site
        check_robots_txt=True,         # off by default
        semaphore_count=2,             # max 2 pages in flight
        mean_delay=1.0,                # polite pause between requests
        max_range=1.0,
        verbose=False,
        user_agent="MyHomelabRAG/1.0 (+https://example.com/bot)",
    )
    OUT.mkdir(exist_ok=True)
    async with AsyncWebCrawler(config=BrowserConfig(headless=True, verbose=False)) as crawler:
        results = await crawler.arun(START_URL, config=config)
        kept = 0
        for r in results:
            if not r.success:
                print(f"skip {r.url}: {r.error_message}")
                continue
            md = r.markdown.fit_markdown or r.markdown.raw_markdown
            if len(md) < 200:
                continue
            name = hashlib.sha1(r.url.encode()).hexdigest()[:12]
            (OUT / f"{name}.md").write_text(md, encoding="utf-8")
            (OUT / f"{name}.json").write_text(json.dumps({"url": r.url}))
            kept += 1
        print(f"crawled {len(results)} pages, kept {kept}")


asyncio.run(main())
