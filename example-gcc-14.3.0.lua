help([==[
    GCC 14.3.0 from https://gcc.gnu.org/gcc-14
]==])

local pathBuilder = require("/home/cms/mielczad/lmod-software-management/pathBuilder")

local base = pathBuilder.make_base_path("gcc/14.3.0", "/software")

conflict("gcc")

-- Setup environment variables

setenv("CC","gcc")

prepend_path("CMAKE_LIBRARY_PATH", pathJoin(base, "lib64"))
prepend_path("CMAKE_PREFIX_PATH", base)
prepend_path("MANPATH", pathJoin(base, "share/man"))

prepend_path("PATH",pathJoin(base,"bin"))
prepend_path("LIBRARY_PATH",pathJoin(base,"lib64"))
prepend_path("LD_LIBRARY_PATH",pathJoin(base,"lib64"))

