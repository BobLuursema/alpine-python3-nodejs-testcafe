FROM node:12-alpine

RUN apk add git

##### FROM python:3.7.3-alpine3.9 #####

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# install ca-certificates so that HTTPS works consistently
# other runtime dependencies for Python are installed later
RUN apk add --no-cache ca-certificates

ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
ENV PYTHON_VERSION 3.7.3

RUN set -ex \
	&& apk add --no-cache --virtual .fetch-deps \
	gnupg \
	tar \
	xz \
	\
	&& wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	&& wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	\
	&& apk add --no-cache --virtual .build-deps  \
	bzip2-dev \
	coreutils \
	dpkg-dev dpkg \
	expat-dev \
	findutils \
	gcc \
	gdbm-dev \
	libc-dev \
	libffi-dev \
	libnsl-dev \
	libtirpc-dev \
	linux-headers \
	make \
	ncurses-dev \
	openssl-dev \
	pax-utils \
	readline-dev \
	sqlite-dev \
	tcl-dev \
	tk \
	tk-dev \
	util-linux-dev \
	xz-dev \
	zlib-dev \
	# add build deps before removing fetch deps in case there's overlap
	&& apk del .fetch-deps \
	\
	&& cd /usr/src/python \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
	--build="$gnuArch" \
	--enable-loadable-sqlite-extensions \
	--enable-shared \
	--with-system-expat \
	--with-system-ffi \
	--without-ensurepip \
	&& make -j "$(nproc)" \
	# set thread stack size to 1MB so we don't segfault before we hit sys.getrecursionlimit()
	# https://github.com/alpinelinux/aports/commit/2026e1259422d4e0cf92391ca2d3844356c649d0
	EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000" \
	&& make install \
	\
	&& find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec scanelf --needed --nobanner --format '%n#p' '{}' ';' \
	| tr ',' '\n' \
	| sort -u \
	| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	| xargs -rt apk add --no-cache --virtual .python-rundeps \
	&& apk del .build-deps \
	\
	&& find /usr/local -depth \
	\( \
	\( -type d -a \( -name test -o -name tests \) \) \
	-o \
	\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
	\) -exec rm -rf '{}' + \
	&& rm -rf /usr/src/python \
	\
	&& python3 --version

# make some useful symlinks that are expected to exist
RUN cd /usr/local/bin \
	&& ln -s idle3 idle \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python3-config python-config

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 19.1.1

RUN set -ex; \
	\
	wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
	\
	python get-pip.py \
	--disable-pip-version-check \
	--no-cache-dir \
	"pip==$PYTHON_PIP_VERSION" \
	; \
	pip --version; \
	\
	find /usr/local -depth \
	\( \
	\( -type d -a \( -name test -o -name tests \) \) \
	-o \
	\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
	\) -exec rm -rf '{}' +; \
	rm -f get-pip.py

##### END PYTHON DOCKERFILE #####

##### FROM testcafe/testcafe #####

RUN apk --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/ upgrade && \
	apk --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/ add \
	chromium xwininfo xvfb dbus eudev ttf-freefont fluxbox procps

RUN npm install -g testcafe && \
	npm cache clean --force && \
	rm -rf /tmp/*

##### END TESTCAFE DOCKERFILE #####

##### FROM AdoptOpenJDK/openjdk-docker #####

RUN apk add --no-cache --virtual .build-deps curl binutils \
	&& GLIBC_VER="2.29-r0" \
	&& ALPINE_GLIBC_REPO="https://github.com/sgerrand/alpine-pkg-glibc/releases/download" \
	&& GCC_LIBS_URL="https://archive.archlinux.org/packages/g/gcc-libs/gcc-libs-8.2.1%2B20180831-1-x86_64.pkg.tar.xz" \
	&& GCC_LIBS_SHA256=e4b39fb1f5957c5aab5c2ce0c46e03d30426f3b94b9992b009d417ff2d56af4d \
	&& ZLIB_URL="https://archive.archlinux.org/packages/z/zlib/zlib-1%3A1.2.11-3-x86_64.pkg.tar.xz" \
	&& ZLIB_SHA256=17aede0b9f8baa789c5aa3f358fbf8c68a5f1228c5e6cba1a5dd34102ef4d4e5 \
	&& curl -LfsS https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub \
	&& SGERRAND_RSA_SHA256="823b54589c93b02497f1ba4dc622eaef9c813e6b0f0ebbb2f771e32adf9f4ef2" \
	&& echo "${SGERRAND_RSA_SHA256} */etc/apk/keys/sgerrand.rsa.pub" | sha256sum -c - \
	&& curl -LfsS ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-${GLIBC_VER}.apk > /tmp/glibc-${GLIBC_VER}.apk \
	&& apk add /tmp/glibc-${GLIBC_VER}.apk \
	&& curl -LfsS ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-bin-${GLIBC_VER}.apk > /tmp/glibc-bin-${GLIBC_VER}.apk \
	&& apk add /tmp/glibc-bin-${GLIBC_VER}.apk \
	&& curl -Ls ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-i18n-${GLIBC_VER}.apk > /tmp/glibc-i18n-${GLIBC_VER}.apk \
	&& apk add /tmp/glibc-i18n-${GLIBC_VER}.apk \
	&& /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true \
	&& echo "export LANG=$LANG" > /etc/profile.d/locale.sh \
	&& curl -LfsS ${GCC_LIBS_URL} -o /tmp/gcc-libs.tar.xz \
	&& echo "${GCC_LIBS_SHA256} */tmp/gcc-libs.tar.xz" | sha256sum -c - \
	&& mkdir /tmp/gcc \
	&& tar -xf /tmp/gcc-libs.tar.xz -C /tmp/gcc \
	&& mv /tmp/gcc/usr/lib/libgcc* /tmp/gcc/usr/lib/libstdc++* /usr/glibc-compat/lib \
	&& strip /usr/glibc-compat/lib/libgcc_s.so.* /usr/glibc-compat/lib/libstdc++.so* \
	&& curl -LfsS ${ZLIB_URL} -o /tmp/libz.tar.xz \
	&& echo "${ZLIB_SHA256} */tmp/libz.tar.xz" | sha256sum -c - \
	&& mkdir /tmp/libz \
	&& tar -xf /tmp/libz.tar.xz -C /tmp/libz \
	&& mv /tmp/libz/usr/lib/libz.so* /usr/glibc-compat/lib \
	&& apk del --purge .build-deps glibc-i18n \
	&& rm -rf /tmp/*.apk /tmp/gcc /tmp/gcc-libs.tar.xz /tmp/libz /tmp/libz.tar.xz /var/cache/apk/*

ENV JAVA_VERSION jdk8u212-b04

RUN set -eux; \
	apk add --virtual .fetch-deps curl; \
	ARCH="$(apk --print-arch)"; \
	case "${ARCH}" in \
	aarch64|arm64) \
	ESUM='b0b3923a48243fa98b71c7fd8ff96def453e07b33156e90cb6851b7b7cacd4b1'; \
	BINARY_URL='https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u191-b12/OpenJDK8U-jre_aarch64_linux_hotspot_8u191b12.tar.gz'; \
	;; \
	amd64|x86_64) \
	ESUM='96d24d94c022b3e414b612cae8829244329d71ad2cce790f099c020f33247e7e'; \
	BINARY_URL='https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u212-b04/OpenJDK8U-jre_x64_linux_hotspot_8u212b04.tar.gz'; \
	;; \
	s390x) \
	ESUM='90554726525b4acb38dae6f1f958711476e5484ff593a0666f43f2a044bb070a'; \
	BINARY_URL='https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u212-b04/OpenJDK8U-jre_s390x_linux_hotspot_8u212b04.tar.gz'; \
	;; \
	ppc64el|ppc64le) \
	ESUM='7e09a9939c0baff8f24277df71844dc121f0bdfa855c2a02fb557e0d3438b9c5'; \
	BINARY_URL='https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u212-b04/OpenJDK8U-jre_ppc64le_linux_hotspot_8u212b04.tar.gz'; \
	;; \
	*) \
	echo "Unsupported arch: ${ARCH}"; \
	exit 1; \
	;; \
	esac; \
	curl -LfsSo /tmp/openjdk.tar.gz ${BINARY_URL}; \
	echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
	mkdir -p /opt/java/openjdk; \
	cd /opt/java/openjdk; \
	tar -xf /tmp/openjdk.tar.gz --strip-components=1; \
	apk del --purge .fetch-deps; \
	rm -rf /var/cache/apk/*; \
	rm -rf /tmp/openjdk.tar.gz;

ENV JAVA_HOME=/opt/java/openjdk \
	PATH="/opt/java/openjdk/bin:$PATH"

#### END JAVA DOCKERFILE #####


##### FROM newtmitch/docker-sonar-scanner #####

run apk add --no-cache curl grep sed unzip bash

WORKDIR /usr/src

RUN curl -o ./sonarscanner.zip -L https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-3.3.0.1492-linux.zip && \
	unzip sonarscanner.zip && \
	rm sonarscanner.zip && \
	mv sonar-scanner-3.3.0.1492-linux /usr/lib/sonar-scanner && \
	ln -s /usr/lib/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner

ENV SONAR_RUNNER_HOME=/usr/lib/sonar-scanner

RUN sed -i 's/use_embedded_jre=true/use_embedded_jre=false/g' /usr/lib/sonar-scanner/bin/sonar-scanner

#### END SONAR SCANNER DOCKERFILE #####

CMD ["/bin/sh"]
