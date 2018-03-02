# This dockerfile is meant to help with setup and testing of
# patroni nodes.  It is designed to use kubernetes to support
# multiple nodes

FROM mdillon/postgis:10-alpine

#RUN apt-get update && apt-get install -y \
#    gettext \
#    python3 \
#    python3-pip \
#    libpq-dev \
#    python3-yaml \
#    python3-psycopg2 \
#    pv \
#    lzop \
#    daemontools

RUN apk add --no-cache --virtual .fetch-deps \
    python3 \
    py3-psycopg2 \
    py3-greenlet \
    py3-gevent \
    py3-psutil
#    && akp del .fetch-deps

COPY ./requirements.txt /opt/requirements.txt
RUN pip3 install -r /opt/requirements.txt

ADD ./scripts/ /scripts/
ADD ./patroni/ /patroni/

EXPOSE 8008 5432

ENTRYPOINT ["/bin/bash", "/scripts/entrypoint.sh"]