local utils = require("director.utils")

---@type ActionGroup
return {
    name = "CMake",
    detect = utils.detectCmake,
    actions = {
        {
            bind = "cc",
            desc = "Compile",
            callback = function ()
                utils.mkdir(vim.fn.getcwd().."/build")
                utils.runInTerminal("cmake --build build")
            end
        },
        {
            bind = "b",
            desc = "Build",
            callback = function ()
                utils.rm(vim.fn.getcwd().."/build")
                utils.runInTerminal("cmake --preset=debug -B build -S .")
            end
        },
        {
            bind = "r",
            desc = "Run",
            callback = function ()
                utils.runInTerminal("\"./build/main.exe\"")
            end
        },
        {
            bind = "cr",
            desc = "Compile and Run",
            callback = function ()
                utils.mkdir(vim.fn.getcwd().."/build")
                utils.runInTerminal("cmake --build build && \"./build/main.exe\"")
            end
        },
        {
            bind = "ts",
            desc = "Test (Silent)",
            callback = function ()
                utils.runInTerminal("cd build && ctest")
            end
        },
        {
            bind = "tl",
            desc = "Test (Verbose)",
            callback = function ()
                utils.runInTerminal("cd build && ctest --verbose")
            end
        },
        {
            bind = "cts",
            desc = "Compile and Test (Silent)",
            callback = function ()
                utils.mkdir(vim.fn.getcwd().."/build")
                utils.runInTerminal("cmake --build build && cd build && ctest")
            end
        },
        {
            bind = "ctl",
            desc = "Compile and Test (Verbose)",
            callback = function ()
                utils.mkdir(vim.fn.getcwd().."/build")
                utils.runInTerminal("cmake --build build && cd build && ctest --verbose")
            end
        },
        {
            bind = "I",
            desc = "Install as Package",
            callback = function ()
                local package_folder = os.getenv("CMakePackagePath")
                if package_folder == nil then
                    print("CMakePackagePath environment variable must be set")
                end
                if utils.isDirectoryEntry(package_folder) then
                    utils.rm(vim.fn.getcwd().."/build")
                    utils.runInTerminal([[cmake -G "MinGW Makefiles" -B build -S . -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc -DCMAKE_EXPORT_COMPILE_COMMANDS=1 --install-prefix "C:\Users\sfman\Packages\Installed" && cmake --build build && cmake --install build --config Debug]])
                else
                    print(package_folder.." is not a valid directory")
                end
            end,
        },
    }
}
