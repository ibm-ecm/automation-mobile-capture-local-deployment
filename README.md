# Mobile Capture Local Deployment

## Requirements

### Operating System

#### Microsoft Windows

##### System Requirements ([Source](https://docs.docker.com/docker-for-windows/install/#system-requirements))
* Windows 10 64-bit: Pro, Enterprise, or Education (Build 15063 or later).
* Hyper-V and Containers Windows features must be enabled.
* The following hardware prerequisites are required to successfully run Client Hyper-V on Windows 10:
    * 64 bit processor with Second Level Address Translation (SLAT)
    * 4GB system RAM
    * BIOS-level hardware virtualization support must be enabled in the BIOS settings. For more information, see Virtualization.

#### macOS

##### System Requirements ([Source](https://docs.docker.com/docker-for-mac/install/#system-requirements))
* Mac hardware must be a 2010 or a newer model, with Intel’s hardware support for memory management unit (MMU) virtualization, including Extended Page Tables (EPT) and Unrestricted Mode. You can check to see if your machine has this support by running the following command in a terminal: sysctl kern.hv_support
* If your Mac supports the Hypervisor framework, the command prints kern.hv_support: 1.
* macOS must be version 10.13 or newer. That is, Catalina, Mojave, or High Sierra. We recommend upgrading to the latest version of macOS.
If you experience any issues after upgrading your macOS to version 10.15, you must install the latest version of Docker Desktop to be compatible with this version of macOS.
Note: Docker supports Docker Desktop on the most recent versions of macOS. That is, the current release of macOS and the previous two releases. Docker Desktop currently supports macOS Catalina, macOS Mojave, and macOS High Sierra.
As new major versions of macOS are made generally available, Docker stops supporting the oldest version and support the newest version of macOS (in addition to the previous two releases).
* At least 4 GB of RAM.
* VirtualBox prior to version 4.3.30 must not be installed as it is not compatible with Docker Desktop.

### Docker Desktop
#### Version
Docker Desktop Community >= 2.1.0.1

### Previously installed version of Mobile Capture
It's important that there are no previous installed version of Mobile Capture on your local Kubernetes cluster.

If possible, before installing this version, reset the cluster by:
1. Open Docker preferences
2. Navigate on the menu to `Kubernetes`
3. Press `Reset Kubernetes Cluster`
4. Wait until the status of Kubernetes is `running`.

If not possible to reset the kubernetes cluster please run the included uninstall script from a terminal:
`$ ./uninstall.sh`

#### Installation
##### Windows
Follow [these instructions](https://docs.docker.com/docker-for-windows/install/) to install Docker Desktop for Windows.
##### macOS
Follow [these instructions](https://docs.docker.com/docker-for-mac/install/) to install Docker Desktop for macOS.

### Kubernetes local cluster
##### Windows
Follow [these instructions](https://docs.docker.com/docker-for-windows/#kubernetes) to enable the Kubernetes cluster on Docker Desktop for Windows.
##### macOS
Follow [these instructions](https://docs.docker.com/docker-for-mac/#kubernetes) to to enable the Kubernetes cluster on Docker Desktop for macOS.

## Installation of Mobile Capture Local Deployment
1. Confirm you have Docker Desktop Community version >= 2.1.0.1
    * Installation instructions link is provided above
2. Confirm Kubernetes cluster on Docker Desktop is enabled
    * Instructions link is provided above
3. Copy docker images file for Mobile Capture, named `docker-images-<number>.tar[.gz]`, to the same directory where this `README` and `install.sh` files are.
    * NOTE: The images file must be the one provided for this version of the script. Version mismatch will not work.
4. Copy Mobile Capture helm chart's directory, named `mobilecapture`, to the same directory where this `README` and `install.sh` files are.
    * NOTE: The helm chart must be the one provided for this version of the script. Version mismatch will not work.
5. Your computer and iOS device must be connected to the same local network
6. Run, from a terminal, the install script, named `install.sh`
    * `$ ./install.sh`
7. Follow on-screen instructions provided by the install script

