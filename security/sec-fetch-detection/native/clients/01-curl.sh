#!/usr/bin/env bash
# Plain curl — baseline "dumb scraper"
exec curl -s "http://localhost:8080/?client=curl" -o /dev/null
