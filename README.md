# karst

access worker nodes from your "surface" OS.

## usage

use the dockerfiles or go full flavor with the `karst` web application.


## known issues

### no copy/paste support in tigervnc client

No copy/paste support in tigervnc client (`:)`) . Submit a PR if you have a solution.

This may be of use https://superuser.com/questions/1081489/how-to-enable-text-copy-and-paste-for-vnc

### Various software fails to start

#### Brave / Chrome

Software such as Brave or Chrome may fail to start.  Special flags may be required at startup, such as:

    brave-browser --no-sandbox --disable-setuid-sandbox

if you know of better solutions, please open a PR>  This seems to be due to lack of access to kernel level operations, such as namespaces.

#### iaito

    ~$ flatpak run org.radare.iaito
    bwrap: No permissions to create new namespace, likely because the kernel does not allow non-privileged user namespaces. See <https://deb.li/bubblewrap> or <file:///usr/share/doc/bubblewrap/README.Debian.gz>.
    error: ldconfig failed, exit status 256

### Mac OS "Screen Share" freezes
VNC can freeze while using the "Screen Sharing" process in Mac OS.  Input will send over the wire, but the screen does not update.

Mac OS console throws messages, such as:

- [0x8bc48c140] Channel could not return listener port.
- viewer did NOT set bit to select session
- RFBSetSharedPasteboard failed with -107

You can tell when the connection is in this bad state as you can see traffic over the wire on the server-side.

There are no complains on the server-side logs (in the .vnc directory if starting `tigervncserver` directly).

Tiger VNC does not seem to have these issues (`brew install tiger-vnc`)

