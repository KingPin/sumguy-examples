FROM alpine:3.22
RUN apk add --no-cache git git-daemon nginx fcgiwrap spawn-fcgi
RUN mkdir -p /srv/git && git init --bare /srv/git/homelab.git && git -C /srv/git/homelab.git config http.receivepack true && git -C /srv/git/homelab.git symbolic-ref HEAD refs/heads/main && chown -R nginx:nginx /srv/git
COPY nginx.conf /etc/nginx/nginx.conf
CMD spawn-fcgi -s /run/fcgi.sock -u nginx -g nginx /usr/bin/fcgiwrap && nginx -g 'daemon off;'
