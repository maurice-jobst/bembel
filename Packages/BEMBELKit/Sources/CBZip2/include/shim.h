// bzip2 lives in the platform SDK (libbz2.tbd + bzlib.h) on every Apple
// platform we ship to, so decompressing DWD's RADOLAN archives needs no
// third-party package — which is what makes ADR 0008's "parse it ourselves"
// decision affordable.
#include <bzlib.h>
