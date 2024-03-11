FROM node:21.7.0

LABEL maintainer="Ares Chen <areschentw@outlook.com>"

RUN apt-get update && \
    apt-get install -y git &&\
    apt-get install -y vim &&\
    apt-get install -y curl &&\
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    npm install -g hexo-cli

# Use Node User
USER 1000:1000

WORKDIR /Hexo

ENTRYPOINT ["bash"]

# docker run -it --restart unless-stopped -v "$(pwd)":/Hexo -p 127.0.0.1:3000:4000 hexo
