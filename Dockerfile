FROM ghcr.io/linuxserver/baseimage-ubuntu:bionic

# set version label
ARG BUILD_DATE
ARG VERSION
ARG CODE_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

# environment settings
ENV HOME="/config"

# Copy in extensions list
COPY vscode.extensions /root/vscode.extensions

RUN \
 echo "**** install node repo ****" && \
 apt-get update && \
 apt-get install -y \
	gnupg && \
 curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
 echo 'deb https://deb.nodesource.com/node_12.x bionic main' \
	> /etc/apt/sources.list.d/nodesource.list && \
 curl -s https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
 echo 'deb https://dl.yarnpkg.com/debian/ stable main' \
	> /etc/apt/sources.list.d/yarn.list && \
 echo "**** install build dependencies ****" && \
 apt-get update && \
 apt-get install -y \
	bsdtar \
	build-essential \
	libx11-dev \
	libxkbfile-dev \
	libsecret-1-dev \
	pkg-config \
	uuid-runtime && \
 echo "**** install runtime dependencies ****" && \
 apt-get install -y \
	git \
	jq \
	nano \
	net-tools \
	nodejs \
	sudo \
	iputils-ping \
	net-tools \
	nmap \
	ack \
	openssl \
	openssh-client \
	unzip \
	wget \
	zip \
	yarn && \
 echo "**** install code-server ****" && \
 if [ -z ${CODE_RELEASE+x} ]; then \
	CODE_RELEASE=$(curl -sX GET "https://api.github.com/repos/cdr/code-server/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]'); \
 fi && \
 CODE_VERSION=$(echo "$CODE_RELEASE" | awk '{print substr($1,2); }') && \
 mkdir -p /root/.code-server/extensions && \
 uuid=$(uuidgen) && \
 while read -r ext; do \
	extention="${ext%%#*}" \
	vendor="${extention%%.*}"; \
	slug="${extention#*.}"; \
	version="${ext##*#}"; \
	echo "Installing vscode extension: ${slug} by ${vendor} @ ${version} "; \
	echo "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${vendor}/vsextensions/${slug}/${version}/vspackage"; \
	curl -JL --retry 5 -o "/tmp/${extention}-${version}.vsix" \
		-H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36" \
		-H "x-market-user-id: ${uuid}" \
		"https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${vendor}/vsextensions/${slug}/${version}/vspackage"; \
	mkdir -p "/root/.code-server/extensions/${extention}-${version}"; \
	bsdtar --strip-components=1 -xf "/tmp/${extention}-${version}.vsix" \
				-C "/root/.code-server/extensions/${extention}-${version}" extension; \
	[ $? -ne 0 ] && exit 1; \
	sleep 1; \
 done < /root/vscode.extensions && \
 ls -la /root/.code-server/extensions/ && \
 yarn config set network-timeout 600000 -g && \
 yarn --production --verbose --frozen-lockfile global add code-server@"$CODE_VERSION" && \
 yarn cache clean && \
 echo "**** clean up ****" && \
 apt-get purge --auto-remove -y \
	bsdtar \
	build-essential \
	libx11-dev \
	libxkbfile-dev \
	libsecret-1-dev \
	pkg-config \
	uuid-runtime && \
 apt-get clean && \
 rm -rf \
	/tmp/* \
	/var/lib/apt/lists/* \
	/var/tmp/*

# add local files
COPY /root /

# ports and volumes
EXPOSE 8443
