local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local addon = AceAddon:NewAddon("RunOnLogin", "AceConsole-3.0")
local Defaults = {
    profile = {
        commands = {},
        debugPrint = false,
    },
}

local db

local function updateOptions()
    if not db.commands then
        db.commands = {}
    end

    addon.options.args.commands = {
        type = "group",
        name = " ",
        inline = true,
        args = {},
    }
    for i, value in ipairs(db.commands) do
        local name, val = strsplit("=", value, 2)
        addon.options.args.commands.args["name" .. i] = {
            order = i * 2,
            type = "input",
            name = "Name",
            width = "double",
            dialogControl = 'EditBox_WithFocusLost',
            get = function() return name end,
            set = function(_, newValue)
                -- Check if the CVar is valid
                local success, error = pcall(C_CVar.GetCVar, newValue)
                if not success then
                    print("Invalid CVar: " .. newValue)
                    return
                end
                -- Check if the CVar is unique
                for j, value in ipairs(db.commands) do
                    local existingName, _ = strsplit("=", value, 2)
                    if existingName == newValue and j ~= i then
                        print("Duplicate CVar: " .. newValue)
                        return
                    end
                end
                db.commands[i] = newValue .. "=" .. val
                name = newValue
            end,
        }
        addon.options.args.commands.args["value" .. i] = {
            order = i * 2 + 1,
            type = "input",
            name = "Value",
            width = "half",
            dialogControl = 'EditBox_WithFocusLost',
            get = function() return val end,
            set = function(_, newValue)
                -- Check if the CVar exists
                local success, error = pcall(C_CVar.GetCVar, name)
                if not success then
                    print("CVar does not exist: " .. name)
                    return
                end
                db.commands[i] = name .. "=" .. newValue
                val = newValue
            end,
        }
        addon.options.args.commands.args["delete" .. i] = {
            order = i * 2 + 2,
            type = "execute",
            name = "Delete",
            width = "half",
            func = function()
                table.remove(db.commands, i)
                addon.options.args.commands.args = {} -- Clear the old options
                updateOptions() -- Update the options
            end,
        }
    end
    addon.options.args.newCommand = {
        order = 1,
        type = "execute",
        name = "Add CVar and Value",
        func = function()
            table.insert(db.commands, "=")
            updateOptions()
        end,
    }
    addon.options.args.debugPrint = {
        type = "toggle",
        name = "Debug Print",
        desc = "Print debug information when setting CVars",
        order = 0,
        get = function() return db.debugPrint end,
        set = function(_, value) db.debugPrint = value end,
    }
    
end

AceGUI:RegisterWidgetType("EditBox_WithFocusLost", function()
    local control = AceGUI:Create("EditBox")
    control:SetCallback("OnEnterPressed", function(self, event, text)
        self:ClearFocus()
    end)
    control:SetCallback("OnEditFocusLost", function(self, event, text)
        self:Fire("OnEnterPressed", self:GetText())
    end)
    control.editbox:HookScript("OnEditFocusLost", function()
        control.button:Click()
    end)
    return AceGUI:RegisterAsWidget(control)
end, 1)

addon.options = {
    name = "Run On Login",
    handler = addon,
    type = "group",
    args = {},
}

function addon:OnInitialize()
    self.db = AceDB:New("RunOnLoginDB", Defaults, "global")
    db = self.db.profile
    updateOptions()
    AceConfig:RegisterOptionsTable("RunOnLogin", self.options)
    self.optionFrames = {
        main = AceConfigDialog:AddToBlizOptions("RunOnLogin", "Run On Login"),
    }
end

function addon:OnEnable()
    if self.db.profile.commands then
        for _, value in ipairs(self.db.profile.commands) do
            local name, val = strsplit("=", value, 2)
            if name and val then
                local success, error = pcall(C_CVar.SetCVar, name, tonumber(val))
                if not success then
                    print("Invalid command: " .. name)
                end
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if addon.db.profile.commands then
            for i, command in ipairs(addon.db.profile.commands) do
                local name, value = strsplit("=", command)
                if name and value then
                    local numberValue = tonumber(value)
                    if numberValue then
                        if addon.db.profile.debugPrint then -- check if the debugPrint setting is enabled
                            print("Setting CVar " .. name .. " to " .. numberValue .. ".")
                        end
                        C_CVar.SetCVar(name, numberValue)
                    else
                        print("Invalid value for CVar " .. name .. ": " .. value)
                    end
                else
                    print("Invalid command: " .. command)
                end
            end
        end
    end
end)
