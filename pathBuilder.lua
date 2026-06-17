

-- if pathBuilder then return end  -- avoid loading twice the same module
local pathBuilder = {}  -- create a table to represent the module


-- this depends on the lmod scripts
loadfile("/usr/share/lmod/lmod/tools/fileOps")
-- require("fileOps")

-- require("Dbg")
loadfile("/usr/share/lmod/lmod/tools/Dbg")

require("Dbg")
local dbg = require("Dbg"):dbg()

-- https://stackoverflow.com/questions/1340230/check-if-directory-exists-in-lua
-- need lua file system
-- https://www.geeks3d.com/hacklab/20210901/how-to-check-if-a-directory-exists-in-lua-and-in-python/
require("lfs")

-- Essential help on modules:
-- https://nachtimwald.com/2014/07/19/writing-lua-modules/


-- Lua Doc: https://www.lua.org/manual/5.3/manual.html#6.4

-- from  https://blog.entek.org.uk/notes/2021/07/27/platform-detection-with-lmod.html
-- export MODULEPATH=$(pwd):$MODULEPATH
--

-- OS variables
local os_fullname = "UNKNOWN"
local os_shortname = "UNKNOWN"
local os_version = "UNKNOWN"
local os_version_major = "UNKNOWN"
local os_distribution = "UNKNOWN"
-- Architecture variables
local arch_platform = "UNKNOWN"
local arch_cpu_fullname = "UNKNOWN"
local arch_cpu_shortname = "UNKNOWN"
local arch_cpu_compat = ""


function pathBuilder.file_exists(file_name)
    local file_found = io.open(file_name, "r")
    if file_found == nil then
        return false
    else
        return true
    end
end

function pathBuilder.get_command_output(command)
    -- Run a command and return the output with whitespace stripped from the end
    return string.gsub(capture(command), '%s+$', '')
end


function pathBuilder.detect_os()
    if pathBuilder.file_exists("/etc/os-release") then
        if (string.len(pathBuilder.get_command_output("grep -i opensuse /etc/os-release")) > 0) or
            (string.len(pathBuilder.get_command_output("grep -i rocky /etc/os-release")) > 0) or
            (string.len(pathBuilder.get_command_output("grep -i ubuntu /etc/os-release")) > 0) then
            -- https://stackoverflow.com/questions/14093452/grep-only-the-first-match-and-stop

            -- universal format between distros
            os_version = pathBuilder.get_command_output("grep VERSION_ID= /etc/os-release | cut -c 13-")
            os_version = string.gsub(os_version,"\"","")

            -- also appears to be universal
            os_distribution = pathBuilder.get_command_output("grep ID= /etc/os-release | cut -c 4- | head -1")
            os_distribution = string.gsub(os_distribution,"\"","")

            -- improve later if needed
            os_version_major = os_version
            os_fullname = os_distribution .. "-" .. os_version_major
        else
            error("Operating System not supported.",1)
            LmodError("Operating System not supported.",1)
        end
    else
        error("Missing /cat/os-release",1)
        Lmoderror("Missing /cat/os-release",1)
    end
end


function pathBuilder.detect_arch()
    -- Detect architecture information
    local cpu_family = pathBuilder.get_command_output("grep -m1 '^cpu family[[:space:]:]\\+' /proc/cpuinfo | sed 's/^cpu family[[:space:]:]\\+\\([0-9]\\+\\)$/\\1/'")
    local cpu_model = pathBuilder.get_command_output("grep -m1 '^model[[:space:]:]\\+' /proc/cpuinfo | sed 's/^model[[:space:]:]\\+\\([0-9]\\+\\)$/\\1/'")
    local cpu_flags = pathBuilder.get_command_output("grep -m1 '^flags[[:space:]:]\\+' /proc/cpuinfo | sed 's/^flags[[:space:]:]\\+\\(.\\+\\)$/\\1/'")

    -- We need to detect for Azure:
    --   Dv3: Haswell, Broadwell, Skylake or Cascade Lake
    --   Fsv2: Skylake or Cascade Lake
    --   NCv2: Broadwell
    --   NCv3: Broadwell
    --   HB: AMD Zen 1
    --   HBv2: AMD Zen 2
    --   HC: Skylake
    -- I also have an IvyBridge system as my home lab, so detect that

    -- cpu_family and cpu_model are integer codes, so we need some lookup-tables (made by examining /proc/cpuinfo on available systems)
    -- Treat Broadwell as being Haswell due to compatible instructon sets
    local cpu_table = {
        ["6"] = {
            ["58"] = "san", -- IvyBridge
            ["63"] = "has", -- Haswell
            ["71"] = "has", -- Broadwell
            ["79"] = "has", -- Broadwell
            ["86"] = "has", -- Broadwell
            ["85"] = "sky", -- Skylake or Cascade Lake
        },
        ["23"] = {
            ["1"] = "zen", -- AMD Zen 1
            ["49"] = "zen2", -- AMD Zen 2
        },
        ["25"] = {
            ["1"] = "zen3", -- AMD Zen 3, our Dell Epyc 7xxx
            ["17"] = "zen4", -- AMD Zen 4 on our test server AMD EPYC 9354P
            ["116"] = "zen4", -- AMD Zen 4, my Tuxedo laptop

        },
    }

    -- Only really care about the family to detect Intel vs AMD (grouped the cpu_table by it for my benefit)
    local cpu_plat_table = {
        ["6"] = "intel",
        ["23"] = "amd",
        ["25"] = "amd",
    }

    -- Human friendly CPU names
    local cpu_names = {
        san = 'SandyBridge of IvyBridge',
        has = 'Haswell or Broadwell',
        sky = 'Skylake',
        cas = 'Cascade Lake',
        zen = 'AMD Zen',
        zen2 = 'AMD Zen2',
        zen3 = 'AMD Zen3',
        zen4 = 'AMD Zen4',
    }

    -- List of compatible architectures (i.e. subset of same instruction set)
    local backward_compat = {
        sky = {'has'},
        cas = {'sky', 'has'},
        zen2 = {'zen'},
        zen3 = {'zen','zen2'},
        zen4 = {'zen','zen2','zen3'},
    }

    local cpu_family_name = cpu_table[cpu_family][cpu_model]

    if cpu_family_name == "sky" then
        -- Skylake with avx512 VNNI is Cascade Lake
        -- see: https://en.wikipedia.org/wiki/AVX-512#CPUs_with_AVX-512
        if string.find(cpu_flags, 'avx512_vnni') then
            cpu_family_name = 'cas'
        end
    end

    arch_platform = cpu_plat_table[cpu_family]
    arch_cpu_shortname = cpu_family_name
    arch_cpu_fullname = cpu_names[arch_cpu_shortname]
    if backward_compat[arch_cpu_shortname] ~= nil then
        --arch_cpu_compat = table.concat(backward_compat[arch_cpu_shortname], ' ')
        arch_cpu_compat = (backward_compat[arch_cpu_shortname])
    end

    dbg.print{"Variable type: ", type(backward_compat[arch_cpu_shortname]), " Value: ", backward_compat[arch_cpu_shortname], "\n"}
end

-- Detection is (relatively) expensive to do, so only do it if needed
-- (Lmod will quite happily unset these variables on unload even if the values don't match)
if mode() == "load" or mode() == "reload" then
    pathBuilder.detect_os()
    pathBuilder.detect_arch()
end


dbg.print{"Variable type: ", type(arch_cpu_compat), " Value: ", arch_cpu_compat, "\n"}

-- -- Export the OS variables
--[[
setenv("HPC_OS_FULL", os_fullname)
-- setenv("HPC_OS_SHORT", os_shortname)
setenv("HPC_OS_VERSION", os_version)
-- setenv("HPC_OS_VERSION_MAJOR", os_version_major)
setenv("HPC_OS_DIST", os_distribution)

-- Export the architecture variables
setenv("HPC_ARCH_CPU_FULLNAME", arch_cpu_fullname)
setenv("HPC_ARCH_CPU_SHORTNAME", arch_cpu_shortname)
setenv("HPC_ARCH_CPU_COMPAT", arch_cpu_compat) -- Do we nneed/want this?
setenv("HPC_ARCH_PLATFORM", arch_platform)
--]]



function pathBuilder.dir_exists_v1(path)
if (lfs.attributes(path, "mode") == "directory") then
    return true
end
    return false
end


-- software is the software/version directory at the end of the path
function pathBuilder.make_base_path(software, software_root)

    -- fully adapted path
    local path_full = pathJoin(software_root, os_fullname, arch_platform, arch_cpu_shortname, software)
    -- only distinguish AMD and Intel
    local path_generic_platform = pathJoin(software_root, os_fullname, "generic" , software)
    -- fully generic software
    local path_generic = pathJoin(software_root, "generic" , software)

    if(pathBuilder.dir_exists_v1(path_full)) then
        return path_full
    elseif arch_cpu_compat ~= "" then -- not empy, i.e. compatbile architecture exists

        dbg.print("Values: ", software_root, "\n")
        dbg.print("Values: ", os_fullname, "\n")
        dbg.print("Values: ", arch_platform, "\n")
        dbg.print("Values: ", software, "\n")

        for i = 1, #arch_cpu_compat do

            local selected_arch = arch_cpu_compat[i]
            dbg.print{"Variable type: ", type(selected_arch), " Value: ", selected_arch, "\n"}

            local compat_path_full = pathJoin(software_root, os_fullname, arch_platform, selected_arch , software)
            dbg.print("Current path: ", compat_path_full, "\n")

            if (pathBuilder.dir_exists_v1(compat_path_full)) then
                dbg.print("Current path found: ", compat_path_full)
                return compat_path_full
            end
        end
    --]]
    elseif (pathBuilder.dir_exists_v1(path_generic_platform))  then
        return path_generic_platform
    elseif pathBuilder.dir_exists_v1(path_generic) then
        return path_generic
    else
    -- I don't really have a good error return
        return pathJoin(software_root,software)
    end
    -- we haven't found the software path, something went wrong
    error("No compatible software path found.",1)
    LmodError("No compatible software path found.",1)
    return nil
end

return pathBuilder


