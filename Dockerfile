# use prebuild alpine image with needed python packages from base branch
FROM registry.paulgo.dev/infra/paulgoio/searxng:base
ENV IMAGE_PROXY= REDIS_URL= LIMITER= BASE_URL= NAME= PRIVACYPOLICY= CONTACT= PROXY= SEARCH_DEFAULT_LANG= SEARCH_ENGINE_ACCESS_DENIED= PUBLIC_INSTANCE= GID=991 UID=991 \
GRANIAN_PROCESS_NAME="searxng" GRANIAN_INTERFACE="wsgi" GRANIAN_HOST="::" GRANIAN_PORT="8080" GRANIAN_WEBSOCKETS="false" GRANIAN_LOOP="uvloop" \
GRANIAN_BLOCKING_THREADS="4" GRANIAN_WORKERS_KILL_TIMEOUT="30" GRANIAN_BLOCKING_THREADS_IDLE_TIMEOUT="300" \
ISSUE_URL=https://github.com/paulgoio/searxng/issues \
GIT_URL=https://github.com/paulgoio/searxng \
GIT_BRANCH=main \
UPSTREAM_COMMIT=b95a3e905d05695a04c424764b8c58020ca38b5c
WORKDIR /usr/local/searxng

# setup searxng user; install build deps and git clone searxng as well as setting the version
RUN addgroup -g ${GID} searxng \
&& adduser -u ${UID} -D -h /usr/local/searxng -s /bin/bash -G searxng searxng \
&& git config --global --add safe.directory /usr/local/searxng \
&& git clone https://github.com/searxng/searxng.git . \
&& git reset --hard ${UPSTREAM_COMMIT} \
&& chown -R searxng:searxng . \
&& su-exec searxng /usr/bin/python3 -m searx.version freeze

# copy custom simple theme css, run.sh and limiter, favicons config
COPY ./src/css/* searx/static/themes/simple/css/
COPY ./src/run.sh /usr/local/bin/run.sh
COPY ./src/limiter.toml /etc/searxng/limiter.toml
COPY ./src/favicons.toml /etc/searxng/favicons.toml

# make run.sh executable, remove css maps (since the builder does not support css maps for now), copy uwsgi server ini, set default settings, precompile static theme files
RUN chmod +x /usr/local/bin/run.sh; \
sed -i -e "/safe_search:/s/0/1/g" \
-e "/autocomplete:/s/\"\"/\"google\"/g" \
-e "/autocomplete_min:/s/4/0/g" \
-e "/port:/s/8888/8080/g" \
-e "/bind_address:/s/127.0.0.1/0.0.0.0/g" \
-e "/http_protocol_version:/s/1.0/1.1/g" \
-e "/X-Content-Type-Options: nosniff/d" \
-e "/X-XSS-Protection: 1; mode=block/d" \
-e "/X-Robots-Tag: noindex, nofollow/d" \
-e "/Referrer-Policy: no-referrer/d" \
-e "/static_use_hash:/s/false/true/g" \
-e "/name: btdigg/s/$/\n    disabled: true/g" \
-e "/name: deviantart/s/$/\n    disabled: true/g" \
-e "/name: vimeo/s/$/\n    disabled: true/g" \
-e "/name: openairepublications/s/$/\n    disabled: true/g" \
-e "/name: wikidata/s/$/\n    disabled: true/g" \
-e "/name: duckduckgo/s/$/\n    disabled: true/g" \
-e "/name: library of congress/s/$/\n    disabled: true/g" \
-e "/name: dictzone/s/$/\n    disabled: true/g" \
-e "/name: genius/s/$/\n    disabled: true/g" \
-e "/name: artic/s/$/\n    disabled: true/g" \
-e "/name: flickr/s/$/\n    disabled: true/g" \
-e "/name: unsplash/s/$/\n    disabled: true/g" \
-e "/name: gentoo/s/$/\n    disabled: true/g" \
-e "/name: openverse/s/$/\n    disabled: true/g" \
-e "/name: google videos/s/$/\n    disabled: true/g" \
-e "/name: yahoo news/s/$/\n    disabled: true/g" \
-e "/name: bing news/s/$/\n    disabled: true/g" \
-e "/name: bing images/s/$/\n    disabled: true/g" \
-e "/name: bing videos/s/$/\n    disabled: true/g" \
-e "/name: tineye/s/$/\n    disabled: true/g" \
-e "/name: qwant.*/s/$/\n    disabled: true/g" \
-e "/- name: brave/s/$/\n    disabled: true/g" \
-e "/name: lingva/s/$/\n    disabled: true/g" \
-e "/name: wallhaven/s/$/\n    disabled: true/g" \
-e "/engine: piped/s/$/\n    disabled: true/g" \
-e "/engine: startpage/s/$/\n    disabled: true/g" \
-e "/shortcut: fd/{n;s/.*/    disabled: false/}" \
searx/settings.yml; \
su-exec searxng /usr/bin/python3 -m compileall -q searx; \
find /usr/local/searxng/searx/static -a \( -name '*.html' -o -name '*.css' -o -name '*.js' -o -name '*.svg' -o -name '*.ttf' -o -name '*.eot' \) \
-type f -exec gzip -9 -k {} \+ -exec brotli --best {} \+

# expose port and set tini as CMD, set searxng user as default for container
USER searxng
EXPOSE 8080
CMD ["/sbin/tini","--","run.sh"]
