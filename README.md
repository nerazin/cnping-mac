cnping
======

This is a macOS-compatible fork of [cntools/cnping](https://github.com/cntools/cnping), a minimal graphical ICMP and HTTP ping tool. On macOS it uses a native Cocoa window and supports unprivileged ICMP ping sockets. The project also includes `searchnet`, a small network scanner.
```
Usage: cnping [host] [period] [extra size] [y-axis scaling] [window title]

	 [host]                 -- domain or IP address of ICMP ping target, or http://[host] i.e. http://google.com
	 [period]               -- period in seconds (optional), default 0.02
	 [extra size]           -- ping packet extra size (above 12), optional, default = 0
	 [const y-axis scaling] -- use a fixed scaling factor instead of auto scaling (optional)
	 [window title]         -- the title of the window (optional)
```
<IMG SRC=https://i.imgur.com/Yj5coKN.gif>

If an http host is listed, the default request is ```HEAD /favicon.ico HTTP/1.1``` since this is usually a very fast, easy operation for the server.  If a specific file or uri is requested, that will be requested instead, i.e. http://github.com/cnlohr will request ```HEAD /cnlohr HTTP/1.1```.

If a regular hostname is requested instead, ICMP (regular ping) will be used.

This allows cnping to be operated in environments where ICMP is prohibited by local computer or network policies.

## Installation

### macOS

CNPing runs natively on macOS 11 or later; you do not need XQuartz or Homebrew. To build it, install the Apple Command Line Tools if you do not already have them:

```sh
xcode-select --install
```

From a checkout of this branch, initialize its graphics submodule and build the app:

```sh
git submodule update --init --recursive
make app
open CNPing.app
```

When launched from Finder, the app asks for a hostname, IP address, or HTTP URL. You can also launch the executable from Terminal with a target and optional parameters:

```sh
make
./cnping 1.1.1.1
./cnping http://example.com
```

The Mac build uses ICMP datagram sockets and normally does not need `sudo`. HTTP mode supports `http://` URLs; HTTPS is not supported. On recent macOS versions, allow local network access if prompted and you want to ping a device on your local network.

In the graph window, press `f` to toggle the graph, `m` to toggle the histogram, or `c` to clear the statistics. Drag the graph to inspect earlier samples; click **LIVE** to return to the latest data. Close the window or press `q` to quit.

### Ubuntu

```
sudo apt install libxinerama-dev libxext-dev libx11-dev build-essential mesa-common-dev libglvnd-dev
git clone https://github.com/cntools/cnping.git
cd cnping/
git submodule update --init --recursive
make linuxinstall
```

'linuxinstall' builds the tool, copies it to your /usr/local/bin folder, and sets the cap_net_raw capability allowing it to create raw sockets without being root.

```
sudo cp cnping /usr/local/bin/
sudo setcap cap_net_raw+ep /usr/local/bin/cnping
```

Note that if only http pinging is requested, you do not need cap_net_raw or root access.

### Windows

A Windows-exe can be cross compiled on Linux, just install the necessary dependencies and compile it:

```
sudo apt install binutils-mingw-w64-i686 gcc-mingw-w64-i686 g++-mingw-w64-i686
make cnping.exe
```

### Other distributions

See our Wiki page for information on more distributions, e.g. Arch, Void, Gentoo or Fedora: [Binary packages and distributions](https://github.com/cntools/cnping/wiki/Binary-packages-and-distributions)
