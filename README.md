# karst

access worker nodes from your "surface" OS.

## usage

use the dockerfiles or go full flavor with the `karst` web application.


## known issues

### Mac OS "Screen Share" freezes
VNC can freeze while using the "Screen Sharing" process in Mac OS.  Input will send over the wire, but the screen does not update.

Mac OS console throws messages, such as:

- [0x8bc48c140] Channel could not return listener port.
- viewer did NOT set bit to select session
- RFBSetSharedPasteboard failed with -107

You can tell when the connection is in this bad state as you can see traffic over the wire on the server-side.

There are no complains on the server-side logs (in the .vnc directory if starting `tigervncserver` directly).

Tiger VNC does not seem to have these issues (`brew install tiger-vnc`)

