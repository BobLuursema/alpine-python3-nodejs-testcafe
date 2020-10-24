# Start with Node image
FROM node:12-alpine

# Add Python

RUN apk add --update --no-cache git python3 rsync openssh openssh-client curl
RUN python3 -m ensurepip
RUN pip3 install --no-cache --upgrade pip

# Add TestCafe

##### FROM testcafe/testcafe #####

RUN apk --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/ upgrade && \
	apk --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/ add \
	chromium xwininfo xvfb dbus eudev ttf-freefont fluxbox procps

RUN npm install -g testcafe && \
	npm cache clean --force && \
	rm -rf /tmp/*

##### END TESTCAFE DOCKERFILE #####

CMD ["/bin/sh"]
