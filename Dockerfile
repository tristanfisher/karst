FROM debian:stable AS base

# -- #
# This is a base container setup for a linux environment.
# This is not intended to be lightweight or "efficient".

# --- #
# base system config
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    apt-transport-https \
    apt-utils \
    cmake \
    curl \
    file \
    flatpak \
    git \
    gpg \
    less \
    locales \
    locate \
    make \
    man \
    net-tools \
    strace \
    sudo \
    tcpdump \
    tmux \
    unzip \
    vim

RUN apt install -y gcc autoconf gdb

FROM base AS gui

# tigervnc https://github.com/TigerVNC/tigervnc
# -> tightvnc has an 8 char password limit (DES) and doesn't seem very actively maintained
# -> libvnc is very cool, but this workstation is meant to just get things done, not specific to writing VNC functionality
# dbus as a message bus for IPC
RUN apt install -y tigervnc-common tigervnc-standalone-server tigervnc-tools tigervnc-scraping-server tigervnc-xorg-extension
RUN apt install -y xterm
RUN apt install -y xinit
RUN apt install -y xfce4
RUN apt install -y xfce4-session
RUN apt install -y x11-utils
RUN apt install -y dbus-x11
RUN mkdir -p /root/tool_downloads/

# RDP client
RUN apt install -y remmina


## languages
# python3: should already be available
# go: via https://go.dev/dl/
FROM gui AS languages

RUN apt install -y g++

# check CPU arch as there's an expectation of ARM/Apple silicon:
# - uname -m
# - arch
# lscpu is also interesting to show more features

# golang
# add a script for getting the filename for go as it isn't
# simple to derive from common shell scripts AFAIK
#   go1.24.5.linux-arm64.tar.gz: uname -m
#   go1.24.5.linux-amd64.tar.gz -- uname -m => x86_64
#
# https://go.dev/dl/go1.24.5.linux-arm64.tar.gz
RUN cat <<EOF > /root/go_download_filename
#!/usr/bin/env python3
from platform import system, machine
version="1.24.5"
os_platform=system().lower()
# arm64 -> mac os with apple silicon;
# aarch64 -> guest on mac os with apple silicon
# amd64 ->  linux on x86 64
arch_golang={"arm64": "arm64","x86_64": "amd64", "aarch64": "arm64"}[machine()]
suffix="tar.gz"
go_file_name = f"go{version}.{os_platform}-{arch_golang}.{suffix}"
print(go_file_name)
EOF

RUN chmod u+x /root/go_download_filename
RUN curl -fsSLo "/root/tool_downloads/$(/root/go_download_filename)" "https://go.dev/dl/$(/root/go_download_filename)"
RUN tar -xzf "/root/tool_downloads/$(/root/go_download_filename)" -C /usr/local/

# rust
RUN curl -fsSo rust_init.sh https://sh.rustup.rs
RUN sh rust_init.sh -y

# java installed in sre_tools layer
FROM languages AS data_fetchers

## web browser
# brave
RUN curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
RUN curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
RUN apt update
RUN apt install -y brave-browser


## byte analysis / software reverse engineering
FROM data_fetchers AS sre_tools

RUN apt install -y hexedit

# radare2
# wget is used by the radare2 install script
RUN apt install -y wget
RUN git clone --depth 1 https://github.com/radareorg/radare2
RUN radare2/sys/install.sh


# iaito
RUN flatpak remote-add flathub https://dl.flathub.org/repo/flathub.flatpakrepo
RUN flatpak install flathub org.radare.iaito -y

# flatpak run org.radare.iaito to run

# ghidra
# https://github.com/NationalSecurityAgency/ghidra
# alternatively: https://github.com/blacktop/docker-ghidra
# openjdk-17-jre-headless is in the package manager, but Ghidra specifically lists Temurin
RUN curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor > /etc/apt/trusted.gpg.d/adoptium.gpg
RUN echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" > /etc/apt/sources.list.d/adoptium.list
RUN apt update
RUN apt install -y temurin-17-jdk

RUN curl -fsSLo /root/tool_downloads/ghidra_master.zip https://github.com/NationalSecurityAgency/ghidra/archive/refs/heads/master.zip
RUN unzip -q /root/tool_downloads/ghidra_master.zip

# there's not an apt repository or easy way to install an updated grade without another
# one-off package manager so use Ghidra's fetch script
RUN  /root/tool_downloads/ghidra-master/gradlew -I gradle/support/fetchDependencies.gradle
RUN /root/tool_downloads/ghidra-master/gradlew buildGhidra

# python 3 also required, with the OS version probably fine


## ftp
# graphical
RUN apt install -y filezilla
# command line
RUN apt install -y vsftpd


FROM data_fetchers AS sec_research

RUN git clone --depth 1 https://gitlab.com/exploit-database/exploitdb.git /opt/exploitdb
RUN ln -sf /opt/exploitdb/searchsploit /usr/local/bin/searchsploit

RUN curl -fsSL https://apt.metasploit.com/metasploit-framework.gpg.key | gpg --dearmor > /usr/share/keyrings/metasploit.gpg
# cat /etc/os-release | grep VERSION_CODENAME | awk 'BEGIN {FS = "=" } ; { print $2 } (or awk -F= '/^VERSION_CODENAME/{print$2}')
# is more exact, but buster works.
RUN echo "deb [signed-by=/usr/share/keyrings/metasploit.gpg] https://apt.metasploit.com/ buster main" | tee /etc/apt/sources.list.d/metasploit.list


FROM sec_research AS user_environment

# to add user with no finger/identifying info, no password login allowed:
RUN adduser --disabled-password --gecos "" user
RUN echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN <<EOF
mkdir -p /root/.vnc/
mkdir -p /home/user/.vnc/
chown -R user:user /home/user/.vnc/
# .Xauthority gets populated on VNC startup
touch /root/.Xauthority
touch /home/user/.Xauthority
chown user:user /home/user/.Xauthority
EOF

# users get their own ports for vnc sessions
RUN echo ":1=root" >> /etc/tigervnc/vncserver.users
RUN echo ":2=user" >> /etc/tigervnc/vncserver.users


# requires being a systemd service
# /usr/lib/systemd/system/tigervncserver\@.service
# https://github.com/TigerVNC/tigervnc/issues/1096

# this doesn't work as systemd is required.  we don't use systemd because systemd tries
# to pull more host OS devices, which is an absolute dearbreaker for a host that could be used for SRE + sec
#RUN cp /usr/lib/systemd/system/tigervncserver\@.service /etc/systemd/system/tigervncserver.service
#RUN systemctl enable tigervncserver@:1.service
#RUN systemctl enable tigervncserver@:2.service

# `systemdctl` will throw: System has not been booted with systemd as init system (PID 1) will throw as bash is our entrypoint
# `service` is still available


# set password either by vncpasswd or tigervncpasswd
# md5sum `which vncpasswd`; md5sum `which tigervncpasswd`
# 0ca168d6252f449100bc231da09165ed  /usr/bin/vncpasswd
# 0ca168d6252f449100bc231da09165ed  /usr/bin/tigervncpasswd
#
# set a default or take an arg to our VNC server to prevent an interactive prompt
# to set a full access and a view only -- echo -e "whateverFullAccess\nwhateverViewOnly"
# -e to interpret backslashes / special chars
# we don't care these default values are in the layer, we just want to
# conceal them from anything else running in a process that could get access to env vars
ENV vnc_password_arg_full_root='lanparty!'
ENV vnc_password_arg_view_root='linuxtx!'

ENV vnc_password_arg_full_user='work work'

# this construction is supposed to work, but is resulting in any password allowing access in read-only
# RUN su root -c 'echo -e "$vnc_password_arg_view_root\n$vnc_password_arg_full_root" | vncpasswd -f > $HOME/.vnc/passwd'
RUN su root -c 'echo -e "$vnc_password_arg_full_root" | vncpasswd -f > $HOME/.vnc/passwd'
RUN chmod 0600 $HOME/.vnc/passwd

RUN su root -c 'echo -e "$vnc_password_arg_full_user" | vncpasswd -f > /home/user/.vnc/passwd'
RUN chmod 0600 /home/user/.vnc/passwd

ENV vnc_password_arg_full_user=''

# write our desired configs for our users
#
# config locations found via: strace -e trace=file tigervncserver
#   newfstatat(AT_FDCWD, "/etc/tigervnc/vncserver-config-defaults", {st_mode=S_IFREG|0644, st_size=10368, ...}, 0) = 0
#   newfstatat(AT_FDCWD, "/etc/tigervnc/vncserver-config-defaults", {st_mode=S_IFREG|0644, st_size=10368, ...}, 0) = 0
#   openat(AT_FDCWD, "/etc/tigervnc/vncserver-config-defaults", O_RDONLY|O_CLOEXEC) = 3
#   newfstatat(AT_FDCWD, "/root/.vnc", {st_mode=S_IFDIR|0755, st_size=4096, ...}, 0) = 0
#   newfstatat(AT_FDCWD, "/root/.vnc/tigervnc.conf", 0xaaaadf41f4a8, 0) = -1 ENOENT (No such file or directory)
#   newfstatat(AT_FDCWD, "/root/.vnc/vnc.conf", 0xaaaadf41f4a8, 0) = -1 ENOENT (No such file or directory)
#   newfstatat(AT_FDCWD, "/root/.vnc/config", 0xaaaadf41f4a8, 0) = -1 ENOENT (No such file or directory)
#   newfstatat(AT_FDCWD, "/root/.vnc/Xtigervnc-session", 0xaaaadf41f4a8, 0) = -1 ENOENT (No such file or directory)
#   newfstatat(AT_FDCWD, "/root/.vnc/Xvnc-session", 0xaaaadf41f4a8, 0) = -1 ENOENT (No such file or directory)
#   newfstatat(AT_FDCWD, "/root/.vnc/xstartup", 0xaaaadf41f4a8, 0) = -1 ENOENT (No such file or directory)
#   newfstatat(AT_FDCWD, "/etc/tigervnc/vncserver-config-mandatory", {st_mode=S_IFREG|0644, st_size=2189, ...}, 0) = 0
#   newfstatat(AT_FDCWD, "/etc/tigervnc/vncserver-config-mandatory", {st_mode=S_IFREG|0644, st_size=2189, ...}, 0) = 0
#   openat(AT_FDCWD, "/etc/tigervnc/vncserver-config-mandatory", O_RDONLY|O_CLOEXEC) = 3

# config order:
# - /etc/tigervnc/vncserver-config-defaults
# - $ENV{HOME}/.vnc/tigervnc.conf per user
# - /etc/tigervnc/vncserver-config-mandatory

# look up available desktop environments via:
# $ ls /usr/share/xsessions/
# lightdm-xsession.desktop  xfce.desktop
# note that .desktop is removed in the session command
# /etc/tigervnc/vncserver-config-mandatory overrides these settings
RUN cat <<EOF > /root/.vnc/tigervnc.conf
\$session="xfce";
\$geometry="1920x1080";
\$localhost="no";
\$AlwaysShared="yes";
EOF

RUN cat <<EOF > /home/user/.vnc/tigervnc.conf
\$session="xfce";
\$geometry="1920x1080";
\$localhost="no";
\$AlwaysShared="yes";
EOF
RUN chown user:user /home/user/.vnc/tigervnc.conf

# "TigerVNC includes libvnc.so, which can be seamlessly loaded during X initialization for enhanced performance. To utilize this feature, create the following file and then restart X:
# https://wiki.archlinux.org/title/TigerVNC
RUN cat <<EOF > /etc/X11/xorg.conf.d/10-vnc.conf
Section "Module"
Load "vnc"
EndSection

Section "Screen"
Identifier "Screen0"
Option "UserPasswdVerifier" "VncAuth"
Option "PasswordFile" "/root/.vnc/passwd"
EndSection
EOF

# todo: gen, xfer x509 certs
# /etc/tigervnc/vncserver-config-defaults
# $SecurityTypes a comma separated list of security types the TigerVNC
#                server will offer. Available are None, VncAuth, Plain,
#                TLSNone, TLSVnc, TLSPlain, X509None, X509Vnc, and X509Plain.
#
# $X509Cert and $X509Key contan the filenames for a certificate and its
#           key that is used for the security types X509None, X509Vnc,
#           and X509Plain.
#
# Default: $X509Cert is auto generated if absent and stored in
#                    ~/.vnc/${HOSTFQDN}-SrvCert.pem
# Default: $X509Key  is auto generated if absent and stored in
#                    ~/.vnc/${HOSTFQDN}-SrvKey.pem

# required for vncserver
ENV USER=root

FROM user_environment AS desktop
RUN echo "UTC" > /etc/timezone
RUN locale-gen en_US en_US.UTF-8

# set the time in the host, independent of the OS to UTC
RUN dpkg-reconfigure tzdata -f noninteractive

# generate and keep our default encoding
# to see available: locale -a
RUN localedef -i en_US -f UTF-8 en_US.UTF-8
RUN locale-gen --keep-existing

ENV LANG=en_US.utf8
ENV LANGUAGE=en_US.utf8
ENV LC_ALL=en_US.utf8
ENV LC_CTYPE=en_US.utf8

# --- #
RUN mkdir -p /srv/
RUN updatedb

# start vncerver with either tigervncserver or vncserver
# $ md5sum $(which tigervncserver)
# d105957af8cd8ff50e760340b6c890dd  /usr/bin/tigervncserver
# $ md5sum $(which vncserver)
# d105957af8cd8ff50e760340b6c890dd  /usr/bin/vncserver

WORKDIR /root/
RUN tigervncserver :1 &

# chown user dir, just in case
RUN chown -R user:user /home/user/

USER user
RUN tigervncserver :2 &

# todo: set xfce launchers https://forum.xfce.org/viewtopic.php?id=11713

ENTRYPOINT ["/usr/bin/env"]
CMD ["tmux"]
