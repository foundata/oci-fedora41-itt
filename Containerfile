FROM fedora:41
LABEL description="Fedora 41, Integration Test Target (ITT) with systemd"
LABEL maintainer="foundata GmbH (https://foundata.com)"

# Inform systemd it's running in a container and specifies the container manager
# type. This affects systemd's behavior in containerized environments (see
# systemd's src/basic/virt.c). Docker users can overwrite this with
# "--env container=docker".
ENV container=podman

# Ensure Python output goes directly to terminal without buffering, preventing
# loss of partial output if an application crashes.
ENV PYTHONUNBUFFERED=1

# Install systemd, remove inconvenient targets and services. Helpful resources
# to determine problematic units to be removed during development:
#   systemctl list-dependencies
#   systemctl list-units --state=waiting
#   systemctl list-units --state=failed
#   https://www.freedesktop.org/software/systemd/man/latest/bootup.html
RUN dnf -y install systemd \
    # General
    && rm -rf "/lib/systemd/system/basic.target.wants/"* \
    && rm -f "/lib/systemd/system/sockets.target.wants/"*"udev"* \
    && rm -f "/lib/systemd/system/sockets.target.wants/"*"initctl"* \
    && rm -f "/lib/systemd/system/"*"ask-password"* \
    && (for i in "/etc/systemd/system/"*".wants/"*; do \
        # delete all files except the ones mentioned
        if  [ "$(basename "${i}")" = "crond.service" ] \
         || [ "$(basename "${i}")" = "systemd-journald-audit.socket" ]; \
        then continue; \
        else rm -f "${i}"; fi; done) \
    && (for i in "/lib/systemd/system/multi-user.target.wants/"*; do\
        # delete all files except the ones mentioned
        if  [ "$(basename "${i}")" = "systemd-update-utmp-runlevel.service" ] \
         || [ "$(basename "${i}")" = "systemd-user-sessions.service" ]; \
        then continue; \
        else rm -f "${i}"; fi; \
    done) \
    # Fedora specific
    && rm -f "/lib/systemd/system/anaconda.target.wants/"*

# Install required packages and clean-up package manager caches afterwards.
# Packages are included for these purposes:
#
# - Overall compatibility and network functionality:
#   iproute, procps-ng, which
#
# - Easier debugging within the container (good feature-to-size ratio):
#   iputils, less, vim-minimal
#
# - Accessing a VM via Ansible:
#   python3, python3-libdnf5, sudo
RUN dnf -y install \
        iproute \
        procps-ng \
        which \
        iputils \
        less \
        vim-minimal \
        python3 \
        python3-libdnf5 \
        sudo \
    && dnf clean all

# Ensure non-interactive sudo commands work in containerized environments where
# TTY allocation is often unavailable or undesired (if needed, it is usually
# allowed on this platform).
RUN sed -i -e 's/\(^Defaults\s*\)\(requiretty\)/\1!\2/' "/etc/sudoers"

# Define volumes for systemd (Podman will do this automatically, but let's add
# this for best-effort Docker compatibility)
VOLUME ["/run", "/run/lock", "/tmp", "/sys/fs/cgroup/systemd", "/var/lib/journal" ]

# Start systemd init
CMD ["/usr/sbin/init"]
