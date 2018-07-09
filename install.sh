#!/bin/sh
set -e
#
# This script provides a mechanism for easy installation of the
# cinder-docker-driver, use with curl or wget:
#  'curl -sSl https://raw.githubusercontent.com/j-griffith/cinder-docker-driver/master/install.sh | sh''
# or
#  'wget -qO- https://raw.githubusercontent.com/j-griffith/cinder-docker-driver/master/install.sh | sh'

# Definition of potential OSS
CDD_OS_COREOS="CoreOS"
CDD_OS_GENERIC="generic"

# Define the release binary to be used
CDD_DRIVER_URL="https://github.com/j-griffith/cinder-docker-driver/releases/download/v0.13/cdd"

pretests() {

   # Must be root
   if [ "$EUID" -ne 0 ]
  	then echo "Please run as root"
  	exit 1
   fi
}


determine_os() {

  # Test for containerlinux
  uname -r | grep -q coreos
  if [ "${?}" -eq 0 ]; then
    CDD_OS="${CDD_OS_COREOS}"  	
  else
    CDD_OS="${CDD_OS_GENERIC}"
  fi
  echo "Operating System: ${CDD_OS}"
}

setenv() {

   # Switch according to OS version
   if [ "${CDD_OS}" = "${CDD_OS_COREOS}" ]; then
      CDD_BIN_DIR="/opt/bin"
   else
      CDD_BIN_DIR="/usr/bin"
   fi
   CDD_BINARY="${CDD_BIN_DIR}/cdd"
   echo "Executable: ${CDD_BINARY}"
 
   CDD_VERSION=${1:-release}
   echo "Version: ${CDD_VERSION}"
      
   echo "Driver URL: ${CDD_DRIVER_URL}"
   
   CDD_LIB_DOCKERDRIVER_DIR="/var/lib/cinder/dockerdriver"
   echo "Driver Directory: ${CDD_LIB_DOCKERDRIVER_DIR}"
   
   CDD_LIB_CINDER_MOUNT_DIR="/var/lib/cinder/mount"
   echo "Mount Directory: ${CDD_LIB_CINDER_MOUNT_DIR}"
}

do_install() {

  # Enssure that all the directory exist
  mkdir -p "${CDD_BIN_DIR}"
  mkdir -p "${CDD_LIB_DOCKERDRIVER_DIR}"
  mkdir -p "${CDD_LIB_CINDER_MOUNT_DIR}"

  # Install the executable
  rm -f "${CDD_BINARY}"
  if [ "${CDD_VERSION}" = 'source' ]; then
    echo "Installing from source tree"
    cp ./_bin/cdd "${CDD_BINARY}"
  else
    echo "Installing release from github repo..."
    curl -sSL -o ${CDD_BINARY} "${CDD_DRIVER_URL}"
    chmod +x "${CDD_BINARY}"
  fi

# install the Service
echo "
[Unit]
Description=\"Cinder Docker Plugin daemon\"
Before=docker.service
Requires=cinder-docker-driver.service

[Service]
TimeoutStartSec=0
ExecStart="${CDD_BINARY}" &

[Install]
WantedBy=docker.service" >/etc/systemd/system/cinder-docker-driver.service

chmod 644 /etc/systemd/system/cinder-docker-driver.service
systemctl daemon-reload
systemctl enable cinder-docker-driver
}

# -------------------------------------------------------------------------

# Run the pretests
pretests

# Determine the underlying Linux distribution, because the installation
# procedure might be different depending on the version
# This script will set the CDD_OS environment variable
determine_os

# Setup Environment for the installation, based on the value of the CDD_OS variable
setenv

# Perform the actual installation
do_install


