# A Couple of Notes

The original source for the lua functions to set variables comes from [https://blog.entek.org.uk/notes/2021/07/27/platform-detection-with-lmod.html](https://blog.entek.org.uk/notes/2021/07/27/platform-detection-with-lmod.html)
This script can set environment variables to describe the architecture based on a curated set of parameters that characterize the underlying operating system and CPU generation.

## Proposed Future Software File Structure

Each final directory will contain the dedicated built software.
The one exception is the generic directory. This is for binary distributions that are not AMD/Intel dependent. This is then linked via symbolic links in the dedicated directories.
Here we need to distinguish between software that had some distribution dependency (such as software built for specific distributions) and those built generically for just "linux".

```test
software_root
└─- distribution
│   └─- intel
│   │   │   skylake
│   |   |   broadwell
│   |   └─- etc.
│   └─- amd
│   |   │   zen3
│   |   |   zen4
│   |   └─- etc.
│   └─- generic
└─- generic  
└─- modules
```

## Variables in Paths

Two options are presented for the use of these variables:

- Dedicated module paths depending on the architecture.
- Application paths via modules depending on platform.

It appears that the recommendation is to use dedicated module directories per platform.
-> But, on closer thought, both the module file as well as the paths in the module file can use the variable, thus being more a game of "copy and paste" - or symbolic links.

```bash
$HPC_OS_SHORT / $HPC_ARCH_PLATFORM / $HPC_ARCH_CPU_SHORTNAME
```

Furthermore, it is possible to encapsulate the entire processing in lua, making it transparent for the user. 

For this code to work, it is necessary to load the presented code and load the platform dependent base path via the script:

```lua
local pathBuilder = require("/(path-to-file-/pathBuilder")
local base = pathBuilder.make_base_path("gcc/14.3.0", "/software")
```

In this case, the software is gcc in version 14.3.0, installed in directory gcc/14.3.0.
The base path for all software is /software.

The `pathBuilder()` function will query the OS from `/etc/os-release` to construct a path of the form `/software/operating-system/amd/zen3/gcc/14.3.0` when running on an EPYC 7713.
As clusters are not known fro highly heterogeneous operating systems, it was decided to role the entire operating system name and version number into a single diretory, such as for example `opensuse-leap-15.5`.

When software is not available for a specific CPU architecture, the code will use a (hard-coded) compatebility list to check alterantive paths.
For example software built on `zen2` should work on `zen3`.
If no match is found, the code will ascend in the path, looking also for a directory called `generic` where architecture-independent code can be supplied, such as for example precompiled binaries. 

There is currently no logic to step through ddifferent operating sytem versions, however by splitting versions into individual directories, it would not be too difficult to include this as an additional logic loop.
