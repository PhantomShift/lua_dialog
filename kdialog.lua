local process = require "@lune/process"
local shared = require "@self/shared"

--[=[
    Lune module for working with kdialog.

    Message boxes (ergo sorry, error, msgbox) return `true` if
    closed by the "Ok" button and `false` otherwise (i.e. pressed escape).
]=]
local kdialog = {}

export type KDialogOptions = {
    geometry:       {number}?,
    default:        string?,
    title:          string?,
    icon:           string?,
    ok_label:       string?,
    yes_label:      string?,
    no_label:       string?,
    cancel_label:   string?,
    continue_label: string?,
}

local clean = shared.clean
local replaceHome = shared.replaceHome

local function kdialogExecute(command: {string}, options: KDialogOptions?) : process.ExecResult
    if options ~= nil then
        for option, value in pairs(options) do
            if option == "geometry" then
                table.insert(command, `--{option}={value[1]}x{value[2]}`)
            elseif option:match("_") then
                table.insert(command, `--{option:gsub("_", "-")} "{value}"`)
            else
                table.insert(command, `--{option} "{value}"`)
            end
        end
    end

    local result = process.exec("kdialog", command)

    return result
end

--- Returns `true` if "Yes" button is selected
function kdialog.yesNo(text: string, options: KDialogOptions?)
    return kdialogExecute({"--yesno", text}, options).code == 0
end


function kdialog.yesNoCancel(text: string, options: KDialogOptions?) : "yes" | "no" | "cancel"
    local out = kdialogExecute({"--yesnocancel", text}, options)
    if out.code == 0 then
        return "yes"
    elseif out.code == 1 then
        return "no"
    end
    return "cancel"
end

--- Returns `true` if "Yes" button is selected
function kdialog.warningYesNo(text: string, options: KDialogOptions?)
    return kdialogExecute({"--warningyesno", text}, options).code == 0
end

--- Returns `true` if "Continue" button is selected
function kdialog.warningContinueCancel(text: string, options: KDialogOptions?)
    return kdialogExecute({"--warningcontinuecancel", text}, options).code == 0
end

function kdialog.warningYesNoCancel(text: string, options: KDialogOptions?)
    local out = kdialogExecute({"--warningyesnocancel", text}, options)
    if out.code == 0 then
        return "yes"
    elseif out.code == 1 then
        return "no"
    end
    return "cancel"
end

function kdialog.sorry(text: string, options: KDialogOptions?)
    return kdialogExecute({"--sorry", text}, options).code == 0
end

function kdialog.detailedSorry(text: string, details: string, options: KDialogOptions?)
    return kdialogExecute({"--detailedsorry", text, details}, options).code == 0
end

function kdialog.error(text: string, options: KDialogOptions?)
    return kdialogExecute({"--error", text}, options).code == 0
end

function kdialog.detailedError(text: string, details: string, options: KDialogOptions?)
    return kdialogExecute({"--detailederror", text, details}, options).code == 0
end

function kdialog.msgBox(text: string, options: KDialogOptions?)
    return kdialogExecute({"--msgbox", text}, options).code == 0
end

function kdialog.inputBox(text: string, init: string?, options: KDialogOptions?) : string?
    local out = kdialogExecute({"--inputbox", text, init or ""}, options)
    if out.code == 1 then return nil end
    return clean(out.stdout)
end

function kdialog.imgBox(file_path: string, options: KDialogOptions?)
    return kdialogExecute({"--imgbox", file_path}, options).code == 0
end

function kdialog.imgInputBox(file_path: string, init: string?, options: KDialogOptions?)
    local out = kdialogExecute({"--imginputbox", file_path, init or ""}, options)
    if out.code == 1 then return nil end
    return clean(out.stdout)
end

function kdialog.password(text: string, options: KDialogOptions?) : string?
    local out = kdialogExecute({"--password", text}, options)
    if out.code == 1 then return nil end
    return clean(out.stdout)
end

function kdialog.newPassword(text: string, options: KDialogOptions?) : string?
    local out = kdialogExecute({"--newpassword", text}, options)
    if out.code == 1 then return nil end
    return clean(out.stdout)
end

function kdialog.textBox(file_path: string, options: KDialogOptions?)
    return kdialogExecute({"--textbox", file_path}, options).code == 0
end

function kdialog.textInputBox(text: string, init: string?, options: KDialogOptions?)
    local out = kdialogExecute({"--textinputbox", text, init or ""}, options)
    if out.code ~= 0 then return nil end
    return clean(out.stdout)
end

function kdialog.comboBox(text: string, items: {string}, default: string?, options: KDialogOptions?) : string?
    local args = {"--combobox", text, table.unpack(items)}
    if default then
        table.insert(args, "--default")
        table.insert(args, default)
    end
    local out = kdialogExecute(args, options)
    if out.code == 1 then return nil end
    return clean(out.stdout)
end

function kdialog.menu(text: string, items: {string}, default: string?, options: KDialogOptions?) : string?
    local args = {"--menu", text}
    for tag, item in ipairs(items) do
        table.insert(args, tostring(tag))
        table.insert(args, item)
    end
    if default ~= nil then
        table.insert(args, "--default")
        table.insert(args, tostring(default))
    end
    local out = kdialogExecute(args, options)
    if out.code == 1 then return nil end
    return items[tonumber(out.stdout:match("%d+")) :: number]
end

--- Returns a table of type `{[number]: boolean}`, where `number` is the number
--- of the item, starting from 1, and `boolean` representing whether it was selected
--- or not.
--- `selected` is a table of items that should be selected by default
function kdialog.checklist(text: string, items: {string}, selected: {[number]: boolean}, options: KDialogOptions?) : {[number]: boolean}?
    local args = {"--checklist", text}
    for tag, item in ipairs(items) do
        table.insert(args, tostring(tag))
        table.insert(args, item)
        table.insert(args, if selected[tag] then "on" else "off")
    end
    local out = kdialogExecute(args, options)
    if out.code == 1 then return nil end
    local result = {}
    for match in out.stdout:gmatch(`"(%d+)"`) do
        result[tonumber(match):: number] = true
    end
    return result
end

--- Returns the number of the item that was selected, starting from 1.
--- `selected` is the number of an item that should be selected by default.
--- Returns first item by default if `selected` is not set.
function kdialog.radioList(text: string, items: {string}, selected: number?, options: KDialogOptions?) : number?
    local args = {"--radiolist", text}
    for tag, item in ipairs(items) do
        table.insert(args, tostring(tag))
        table.insert(args, item)
        table.insert(args, if tag == selected then "on" else "off")
    end
    local out = kdialogExecute(args, options)
    if out.code == 1 then return nil end
    return tonumber(out.stdout:match("%d+"))
end

export type KDialogPopupIcon = "dialog-information" | "dialog-error" | "dialog-warning"
--- Returns nothing; does not stall the thread.
--- This dialog is rather limited in functionality, consider using `notify-send` instead
function kdialog.passivePopup(text: string, timeout: number, icon: KDialogPopupIcon?, options: KDialogOptions?)
    local args = {"--passivepopup", text, tostring(timeout)}
    if icon ~= nil then
        table.insert(args, "--icon")
        table.insert(args, icon)
    end
    kdialogExecute(args, options)
end

function kdialog.getOpenFilename(startDir: string, filter: {string}?, mulitple: boolean?, options: KDialogOptions?) : string?
    local args = {"--getopenfilename", replaceHome(startDir), `{filter and table.concat(filter, "\n") or ""}\nFile (*.*)`}
    if mulitple then
        table.insert(args, "--multiple")
    end
    local out = kdialogExecute(args, options)
    if out.code == 1 then return nil end
    return clean(out.stdout)
end

function kdialog.getSaveFilename(startDir: string, filter: {string}?, options: KDialogOptions?) : string?
    local out = kdialogExecute({"--getsavefilename", replaceHome(startDir), `{filter and table.concat(filter, "\n") or ""}\nFile (*.*)`}, options)
    if out.code == 1 then return nil end
    return clean(out.stdout)
end

function kdialog.getExistingDirectory(startDir: string, options: KDialogOptions?) : string?
    local out = kdialogExecute({"--getexistingdirectory", replaceHome(startDir)}, options)
    if out.code == 1 then return nil end
    return clean(out.stdout)
end

function kdialog.getOpenUrl(startDir: string, filter: {string}?, multiple: boolean, options: KDialogOptions?) : string?
    local args = {"--getopenurl", replaceHome(startDir), `{filter and table.concat(filter, "\n") or ""}\nFile (*.*)`}
    if multiple then
        table.insert(args, "--multiple")
    end
    local out = kdialogExecute(args, options)
    if out.code == 1 then return nil end
    return clean(out.stdout)
end

function kdialog.getSaveUrl(startDir: string, filter: {string}?, options: KDialogOptions?) : string?
    local out = kdialogExecute({"--getsaveurl", replaceHome(startDir), `{filter and table.concat(filter, "\n") or ""}\nFile (*.*)`}, options)
    if out.code == 1 then return nil end
    return clean(out.stdout)
end

type IconContext = "Actions" | "Applications" | "Devices" | "MimeTypes" | "Animation" | "Category" | "Emblem" | "Emote" | "Place" | "FileSystem" | "StatusIcon" | "Iternational"
function kdialog.getIcon(context: IconContext?, options: KDialogOptions?) : string?
    local out = kdialogExecute({"--geticon", context or "All"}, options)
    if out.code == 1 then return nil end
    return clean(out.stdout)
end

--- Wrapper around qdbus for interacting with a progress bar
local KDialogProgressBar = {}
KDialogProgressBar.__index = KDialogProgressBar
function KDialogProgressBar.new(reference: string, path: string, autoclose: boolean?, size: number)
    return setmetatable({reference = reference, path = path, size = size, autoclose = autoclose, progress = 0, alive = true}, KDialogProgressBar)
end
type KDialogProgressBar = typeof(KDialogProgressBar.new("", "", false, 0))
function KDialogProgressBar:SetLabelText(text: string)
    process.exec("qdbus", {self.reference, self.path, "setLabelText", text})
end
function KDialogProgressBar:SetProgress(n: number)
    process.exec("qdbus", {self.reference, self.path, "Set", "", "value", tonumber(n)})
    self.progress = n
    if self.autoclose and n == self.size then
        self:Close()
    end
end
function KDialogProgressBar:GetProgress() : number
    return self.progress
end
function KDialogProgressBar:Close()
    process.exec("qdbus", {self.reference, self.path, "close"})
    self.alive = false
end

function kdialog.progressBar(text: string, size: number, autoclose: boolean?, options: KDialogOptions?) : KDialogProgressBar?
    local out = kdialogExecute({"--progressbar", text, tostring(size)}, options)
    if out.code == 1 then return nil end
    local ref, path = table.unpack(clean(out.stdout):split(" "))
    return KDialogProgressBar.new(ref, path, autoclose, size)
end

--- `format` accepts %x and %d, i.e. the default `"#%2x%2x%2x"` or
--- `"R: %3d, G: %3d, B: %3d"`.
--- `default` is expected to be in HTML hex format (`"#FFFFFF"`).
function kdialog.getColor(format: string?, default: string?, options: KDialogOptions?) : string?
    local args = {"--getcolor"}
    if format then
        table.insert(args, "--format")
        table.insert(args, format)
    end
    if default then
        table.insert(args, "--default")
        table.insert(args, default)
    end
    local out = kdialogExecute(args, options)
    if out.code == 1 then return nil end
    return clean(out.stdout)
end

function kdialog.slider(text: string, min: number, max: number, step: number, options: KDialogOptions?) : number?
    local out = kdialogExecute({"--slider", text, tostring(min), tostring(max), tostring(step)}, options)
    -- for some reason this is reversed on slider and calendar?
    if out.code == 0 then return nil end
    return tonumber(out.stdout:match("%d+"))
end

--- `format` is expected to be in Qt-style; defaults to "ddd MMM d yyyy"
function kdialog.calendar(text: string, format: string?, options: KDialogOptions?)
    local args = {"--calendar", text}
    if format then
        table.insert(args, "--dateformat")
        table.insert(args, format)
    end
    local out = kdialogExecute(args, options)
    if out.code == 0 then return nil end
    return clean(out.stdout)
end

return kdialog