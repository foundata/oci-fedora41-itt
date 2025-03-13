FROM fedora:41
LABEL maintainer="foundata GmbH (https://foundata.com)"
LABEL description="Fedora 41, Integration Test Target (ITT) with systemd"

# Inform systemd it's running in a container and specifies the container manager
# type. This affects systemd's behavior in containerized environments (see
# systemd's src/basic/virt.c). Docker users can overwrite this with
# "--env container=docker".
ENV container=podman

# Ensure Python output goes directly to terminal without buffering, preventing
# loss of partial output if an application crashes.
ENV PYTHONUNBUFFERED=1

# Update system and clean DNF cache.
# Commented out as we rely on regular rebuilds of the base image until EOL
# instead, avoiding the downsides of forced timestamp updates and increased
# layer sizes when the used base image was optimized.
#RUN dnf clean all && dnf makecache && dnf -y update

# Install systemd
RUN dnf -y install systemd && \
    # Remove unnecessary targets and services, keep essentials only
    (cd "/lib/systemd/system/sysinit.target.wants/"; for i in *; do [ "${i}" = "systemd-tmpfiles-setup.service" ] || rm -f "${i}"; done) && \
    rm -f /lib/systemd/system/multi-user.target.wants/* && \
    rm -f /etc/systemd/system/*.wants/* && \
    rm -f /lib/systemd/system/local-fs.target.wants/* && \
    rm -f /lib/systemd/system/sockets.target.wants/*udev* && \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl* && \
    rm -f /lib/systemd/system/basic.target.wants/* && \
    rm -f /lib/systemd/system/anaconda.target.wants/*

# Install required packages and clean-up package manager caches afterwards.
# Packages are included for these purposes:
#
# - Overall compatibility and network functionality:
#   iproute, which
#
# - Easier debugging within the container (good feature-to-size ratio):
#   iputils, less, procps-ng, vim-minimal
#
# - Accessing a VM via Ansible:
#   python3, python3-libdnf5, sudo
RUN dnf -y install \
        iproute \
        which \
        iputils \
        less \
        procps-ng \
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
