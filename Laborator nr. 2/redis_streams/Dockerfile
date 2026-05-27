FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        ruby \
        ruby-dev \
        python3 \
        python3-pip \
    && gem install redis \
    && pip3 install redis \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash student
USER student

WORKDIR /home/student/lab2

CMD ["tail", "-f", "/dev/null"]
