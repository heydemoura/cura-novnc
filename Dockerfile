# Get and install Easy noVNC.
FROM golang:1.14-buster AS easy-novnc-build
WORKDIR /src
RUN go mod init build && \
    go get github.com/geek1011/easy-novnc@v1.1.0 && \
    go build -o /bin/easy-novnc github.com/geek1011/easy-novnc

# Get TigerVNC and Supervisor for isolating the container.
FROM debian:buster
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends openbox tigervnc-standalone-server supervisor gosu && \
    rm -rf /var/lib/apt/lists && \
    mkdir -p /usr/share/desktop-directories

# Get all of the remaining dependencies for the OS, VNC, and Cura (additionally Firefox-ESR to sign-in to Ultimaker if you'd like).
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends lxterminal nano wget openssh-client rsync ca-certificates xdg-utils htop tar xzip gzip bzip2 zip unzip && \
    rm -rf /var/lib/apt/lists

RUN apt update && apt install -y --no-install-recommends --allow-unauthenticated \
        lxde gtk2-engines-murrine gnome-themes-standard gtk2-engines-pixbuf gtk2-engines-murrine arc-theme \
        freeglut3 libgtk2.0-dev libwxgtk3.0-gtk3-dev libwx-perl libxmu-dev libgl1-mesa-glx libgl1-mesa-dri  \
        xdg-utils locales locales-all pcmanfm jq curl git firefox-esr \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Install Cura!
ADD get_latest_cura_release.sh cura/
WORKDIR /cura

RUN chmod +x /cura/get_latest_cura_release.sh \
  && latestCura=$(/cura/get_latest_cura_release.sh url) \
  && curaReleaseName=$(/cura/get_latest_cura_release.sh name) \
  && curl -sSL ${latestCura} > ${curaReleaseName} \
  && rm -f /cura/releaseInfo.json \
  && chmod +x /cura/${curaReleaseName} \
  && /cura/${curaReleaseName} --appimage-extract \
  && rm /cura/${curaReleaseName} \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get autoclean \
  && groupadd cura \
  && useradd -g cura --create-home --home-dir /home/cura cura \
  && mkdir -p /cura \
  && chown -R cura:cura /cura /home/cura

COPY --from=easy-novnc-build /bin/easy-novnc /usr/local/bin/
COPY menu.xml /etc/xdg/openbox/
COPY supervisord.conf /etc/
EXPOSE 8080

VOLUME /home/cura/

# It's time! Let's get to work!
CMD ["bash", "-c", "chown -R cura:cura /dev/stdout && exec gosu cura supervisord"]