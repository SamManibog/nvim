-- ----------------------------------------------------------------------------
-- command definitions --------------------------------------------------------
-- ----------------------------------------------------------------------------

-- Make command ---------------------------------------------------------------
-- function definition
vim.api.nvim_create_user_command("Make", function()
    os.execute("cd \"" .. vim.fn.getcwd() .. "\\build\" & make")
end, {desc = "run makefile from build folder", nargs = '?'})
-- NewProject command ---------------------------------------------------------
-- helper classes
local folderObject, fileObject

--function definition
vim.api.nvim_create_user_command("NewProject", function(args)
    local projectName = vim.fn.input("Provide project name: ")
    local lang = args['args']
    local directory
    local cwd = vim.fn.getcwd()

    --create main directory
    if (lang == "") then --default---------------------------------------------
        directory = folderObject:new(
            projectName,
            {
                folderObject:new("src"),
                folderObject:new("bin"),
                folderObject:new("res"),
                folderObject:new("lib"),
                folderObject:new("include"),
            },
            nil
        )
        lang = "general"

    elseif (lang == "cpp") then--cpp-------------------------------------------
        directory = folderObject:new(
        projectName,
        {
            folderObject:new(
            "src",
            nil,
            {
                fileObject:new("main.cpp", {
                    "#include <iostream>",
                    "",
                    "int main() {",
                    "   std::cout<<\"Hello World\";",
                    "   return 0;",
                    "}"
                }),
            }),
            folderObject:new("bin"),
            folderObject:new("res"),
            folderObject:new("lib"),
            folderObject:new("include"),
            folderObject:new("build"),
        },
        {
            fileObject:new("CMakeLists.txt",
            {
                "cmake_minimum_required(VERSION 3.20)",
                "project(" .. projectName .. ")",
                "set(CMAKE_CXX_STANDARD 20)",
                "add_executable(${PROJECT_NAME} src/main.cpp)",
            })
        }
        )

    else
        print("invalid language " .. lang .. "no directory built")
        return
    end
    directory:build(cwd)

    --finalize directory
    if (lang == "cpp") then
        print("cd " .. cwd .. "\\" .. projectName)
        os.execute(
        "cd \"" .. cwd .. "\\" .. projectName .. "\" & cmake -B build " ..
        "-D CMAKE_EXPORT_COMPILE_COMMANDS=1 -D CMAKE_C_COMPILER=gcc " .. 
        "-D CMAKE_CXX_COMPILER=g++ -G \"MinGW Makefiles\" -S . "
        )
    end
    print("Created " .. lang .. " project directory")

end, {desc = "create base project/dir for supplied language", nargs = '?'})

-- ----------------------------------------------------------------------------
-- helper functions, objects, etc. --------------------------------------------
-- ----------------------------------------------------------------------------

-- NewProject helpers ---------------------------------------------------------
folderObject = {
    name = "",
    folders = {},
    files = {},
    id = 0
}

local idnum = 0
function folderObject:new (name, folders, files)
    local output = {}
    setmetatable(output, self)
    output.name = name
    output.id = idnum
    idnum = idnum + 1
    output.folders = folders or {}
    output.files = files or {}

    function output:build (path)
        print("Attempting to create directory " .. self.name .. " " .. self.id)
        local dirPath = path .. "\\" .. name
        os.execute("mkdir \"" .. dirPath .. "\"")
        for key,value in pairs(self.folders) do
            value:build(dirPath)
        end
        for key,value in pairs(self.files) do
            value:build(dirPath)
        end
        print("Directory \"" .. self.name .. "\" created")
    end

    return output
end


fileObject = {
    name = "",
    lines = {}
}

function fileObject:new (name, lines)
    local output = {}
    setmetatable(output, self)
    output.name = name
    output.lines = lines or {}

    function output:build (path)
        print("Attempting to create file " .. self.name)
        local file = io.open(path .. "\\" .. self.name, "w")
        if (file) then
            for key,value in pairs(self.lines) do
                file:write(value .. "\n")
            end
            file:close()
            print("Success")
        else
            print("Failed")
        end
    end

    return output
end

