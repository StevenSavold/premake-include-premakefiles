include "../include-premakefiles.lua"

workspace "Test"
    configurations { "Test" }

    include_premakefiles
    {
        "hello/world.cpp",
        "premake5.lua",
        "goodbye/world.h",
        "goodbye/dave",
        "my/cool/test/.editorconfig"
    }
