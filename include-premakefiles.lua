-- Implement the solution_items command for solution-scope files
require('vstudio')

premake.api.register {
    name = "include_premakefiles",
    scope = "workspace",
    kind = "list:string",
}

local function GenerateProjectHeader(projectTypeGUID, folderName, projectGUID)
    premake.push("Project(\"" .. projectTypeGUID .. "\") = \"" .. folderName .. "\", \"" .. folderName .. "\", \"{" .. projectGUID .. "}\"")
    premake.push("ProjectSection(SolutionItems) = preProject")
end

local function GenerateProjectFooter()
    premake.pop("EndProjectSection")
    premake.pop("EndProject")
end

local function GetTopLevelFolderFromFile(filepath)
    startpos, endpos = string.find(filepath, "/")
    if startpos == nil then
        return filepath
    end
    return string.sub(filepath, 0, startpos - 1)
end

local function GetSubfolder(filepath)
    startpos, endpos = string.find(filepath, "/")
    if endpos == nil then
        return ""
    end
    return string.sub(filepath, startpos + 1, #filepath)
end

local function BuildHeirarchy(file_list)
    local output = {}
    for _, file in ipairs(file_list) do
        toplevel = GetTopLevelFolderFromFile(file)
        subfolder = GetSubfolder(file)
        if #subfolder == 0 then
            output[toplevel] = subfolder
            goto continue
        end
        if not table.contains(table.keys(output), toplevel) then
            output[toplevel] = {}
        end
        table.insert(output[toplevel], subfolder)
        ::continue::
    end

    for key, value in pairs(output) do
        if type(value) == "table" then
            output[key] = BuildHeirarchy(value)
        end
    end

    return output
end

local function GenerateProjects(projectName, filetree, projectTypeGUID, partial_path, wks)
    -- Generate top level for this depth
    GenerateProjectHeader(projectTypeGUID, projectName, os.uuid(projectName))
    for folder, subtree in pairs(filetree) do
        if not (type(subtree) == "table") then
            local parent_path = ""
            if #partial_path == 0 then
                parent_path = folder
            else
                parent_path = partial_path .. "/" .. folder
            end

            premake.w(parent_path .. " = " .. parent_path)
        end
    end
    GenerateProjectFooter()

    -- Generate all sub projects
    for folder, subtree in pairs(filetree) do
        if type(subtree) == "table" then
            local parent_path = ""
            if #partial_path == 0 then
                parent_path = folder
            else
                parent_path = partial_path .. "/" .. folder
            end
            GenerateProjects(folder, subtree, projectTypeGUID, parent_path, wks)
        end
    end
end

-- local function GenerateGroupTreeEntries(filetree, root_path, tree)
--     if not type(filetree) == "table" then
--         return
--     end

--     for folder, subtree in pairs(filetree) do
--         if type(subtree) == "table" then
--             premake.tree.add(tree, root_path .. folder, { ["uuid"] = os.uuid(folder) })
--             GenerateGroupTreeEntries(subtree, root_path .. folder .. "/", tree)
--         end
--     end
-- end

local function GenerateGlobalSectionValues(filetree)
    local nodeList = {}

    for node, subtree in pairs(filetree) do
        if type(subtree) == "table" then
            local sub_uuid = GenerateGlobalSectionValues(subtree)
            if #sub_uuid == 0 then
                table.insert(nodeList, os.uuid(node))

            else
                local parent_uuid = os.uuid(node)
                for _, id in ipairs(sub_uuid) do
                    premake.w("{" .. id .. "} = {" .. parent_uuid .. "}")
                end
                table.insert(nodeList, parent_uuid)
            end
        end
    end

    return nodeList
end

premake.override(premake.vstudio.sln2005, "projects", function(base, wks)
    if wks.include_premakefiles and #wks.include_premakefiles > 0 then
        local solution_folder_GUID = "{2150E333-8FDC-42A3-9474-1A3956D46DE8}" -- See https://www.codeproject.com/Reference/720512/List-of-Visual-Studio-Project-Type-GUIDs

        -- For each path, check if its in a subfolder,
        -- for each subfolder, generate a solution items 
        -- project for it and add the files in that 
        -- subfolder to it.

        -- For each generated project, emit the "globals"
        -- reference for it to structure the folders properly

        
        local structure = BuildHeirarchy(wks.include_premakefiles)
        GenerateProjects("Premake Files", structure, solution_folder_GUID, "", wks)

        premake.push("Global")
        premake.push("GlobalSection(NestedProjects) = preSolution")

        local root_nodes = GenerateGlobalSectionValues(structure)
        for _, id in ipairs(root_nodes) do
            premake.w("{" .. id .. "} = {" .. os.uuid("Premake Files") .. "}")
        end

        premake.pop("EndGlobalSection")
        premake.pop("EndGlobal")

        -- print(table.tostring(structure, 10))
        
        -- GenerateGroupTreeEntries(structure, "/", premake.workspace.grouptree(wks))
        -- print(table.tostring(premake.workspace.grouptree(wks), 5))

    end
    base(wks)
end)
