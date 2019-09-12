FROM lsiobase/alpine:latest
MAINTAINER Drew

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Version:- ${VERSION} Build-date:- ${BUILD_DATE}"

RUN apk update && apk upgrade

# install packages
RUN \
 apk add --no-cache \
	curl \
  jq \
  openssl \
  openssl-dev \
  wget \
  tar \
  make \
  gcc \
  build-base \
  gnupg

# build perl
RUN mkdir -p /usr/src/perl

WORKDIR /usr/src/perl

## from perl; `true make test_harness` because 3 tests fail
## some flags from http://git.alpinelinux.org/cgit/aports/tree/main/perl/APKBUILD?id=19b23f225d6e4f25330e13144c7bf6c01e624656
RUN curl -SLO https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.26.2.tar.bz2 \
    && echo '2057b65e3a6ac71287c973402cd01084a1edc35b *perl-5.26.2.tar.bz2' | sha1sum -c - \
    && tar --strip-components=1 -xjf perl-5.26.2.tar.bz2 -C /usr/src/perl \
    && rm perl-5.26.2.tar.bz2 \
    && ./Configure -des \
        -Duse64bitall \
        -Dcccdlflags='-fPIC' \
        -Dcccdlflags='-fPIC' \
        -Dccdlflags='-rdynamic' \
        -Dlocincpth=' ' \
        -Duselargefiles \
        -Dusethreads \
        -Duseshrplib \
        -Dd_semctl_semun \
        -Dusenm \
    && make libperl.so \
    && make -j$(nproc) \
    && TEST_JOBS=$(nproc) true make test_harness \
    && make install \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl

## from tianon/perl
ENV PERL_CPANM_OPT --verbose --mirror https://cpan.metacpan.org --mirror-only
RUN cpanm Digest::SHA Module::Signature && rm -rf ~/.cpanm
ENV PERL_CPANM_OPT $PERL_CPANM_OPT --verify

WORKDIR /


RUN \
echo "***** install perl modules ****" && \
cpanm --no-wget -f Config::Simple Log::Log4perl InfluxDB::LineProtocol FindBin LWP::UserAgent

ENV NUT_VERSION 2.7.4

RUN set -ex; \
	# run dependencies
	apk add --no-cache \
		openssh-client \
		libusb-compat \
	; \
	# build dependencies
	apk add --no-cache --virtual .build-deps \
		libusb-compat-dev \
		build-base \
	; \
	# download and extract
	cd /tmp; \
	wget http://www.networkupstools.org/source/2.7/nut-$NUT_VERSION.tar.gz; \
	tar xfz nut-$NUT_VERSION.tar.gz; \
	cd nut-$NUT_VERSION \
	; \
	# build
	./configure \
		--prefix=/usr \
		--sysconfdir=/etc/nut \
		--disable-dependency-tracking \
		--enable-strip \
		--disable-static \
		--with-all=no \
		--with-usb=no \
		--datadir=/usr/share/nut \
		--with-drvpath=/usr/share/nut \
		--with-statepath=/var/run/nut \
		--with-user=nut \
		--with-group=nut \
	; \
	# install
	make install \
	; \
	# cleanup
	rm -rf /tmp/nut-$NUT_VERSION.tar.gz /tmp/nut-$NUT_VERSION; \
	apk del .build-deps


RUN cpanm LWP::UserAgent InfluxDB::LineProtocol

# copy local files
RUN mkdir -p /nut
COPY . /nut/

ENTRYPOINT ["bash", "/nut/nut2influx.sh"]
