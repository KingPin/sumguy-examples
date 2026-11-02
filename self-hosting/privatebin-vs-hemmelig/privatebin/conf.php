;<?php http_response_code(403); /*
; The line above keeps the file unreadable if a web server ever serves it as PHP.
; Everything not set here falls back to PrivateBin's built-in defaults.

[main]
; Pre-tick "Burn after reading" for every new paste.
burnafterreadingselected = true
; Comments need a readable paste, which fights burn-after-reading.
discussion = false
; Bytes per paste or comment. 10000000 is the value in the sample config.
sizelimit = 10000000

[expire]
; Must match a key in [expire_options] (defaults: 5min, 10min, 1hour, 1day,
; 1week, 1month, 1year, never).
default = "1day"

[traffic]
; Seconds between paste creations from one IP. 0 disables the limit.
limit = 10

; PrivateBin refuses to start without these two sections, even if you want the defaults.
[model]
class = Filesystem

[model_options]
dir = PATH "data"
