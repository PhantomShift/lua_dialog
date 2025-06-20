local process = require "@lune/process"
local stdio = require "@lune/stdio"
local DateTime = require "@lune/datetime"

local zenity = require "@self/zenity"
local kdialog = require "@self/kdialog"
local notify = require "@self/notify"

local dialog = {
    zenity = zenity,
    kdialog = kdialog,
    notify = notify
}

local PREFERRED_INTERFACE: "kdialog" | "zenity" | "none" = "none"
do
    local function findBinary(name: string) : boolean
        local result = process.exec("whereis", {name})
        if not result.ok then return false end
        local path = result.stdout:gsub(`^{name}:`, "")
        return not (path == "")
    end
    local kdialogExists = findBinary("kdialog")
    local zenityExists = findBinary("zenity")
    if not (kdialogExists or zenityExists) then
        stdio.ewrite("[WARNING] lua_dialog depends on either zenity or kdialog being installed on linux\n")
    end

    if kdialogExists and not zenityExists then
        PREFERRED_INTERFACE = "kdialog"
    elseif zenityExists and not kdialogExists then
        PREFERRED_INTERFACE = "zenity"
    elseif process.env.LUA_DIALOG_PREFERRED then
        PREFERRED_INTERFACE = process.env.LUA_DIALOG_PREFERRED
    else
        local xdg_desktop = process.env.XDG_CURRENT_DESKTOP
        if xdg_desktop == "KDE" then
            PREFERRED_INTERFACE = "kdialog"
        elseif xdg_desktop == "GNOME" or xdg_desktop == "GTK" then
            PREFERRED_INTERFACE = "zenity"
        else
            stdio.ewrite("[WARNING] lua_dialog is unsure which interface this desktop prefers; defaulting to zenity, even if it is not installed\n")
            PREFERRED_INTERFACE = "zenity"
        end
    end
end

--- Force `PREFERRED_INTERFACE` to be a certain value.
--- Consider using the modules directly instead.
function dialog.overridePreferredInterface(interface: "kdialog" | "zenity")
    PREFERRED_INTERFACE = interface
end

export type DialogOptions = {
    title:          string?,
    geometry:       {number}?,
    ok_label:       string?,
    cancel_label:   string?
}

local function dialogToZennity(options: DialogOptions?) : zenity.ZenityOptions?
    if not options then return nil end

    local result = {
        title = options.title,
        ok_label = options.ok_label,
        cancel_label = options.cancel_label,
    }

    if options.geometry then
        result.width = options.geometry[1]
        result.height = options.geometry[2]
    end

    return result :: zenity.ZenityOptions
end
local function dialogToKdialog(options: DialogOptions?) : kdialog.KDialogOptions?
    return options :: kdialog.KDialogOptions?
end

function dialog.yesNo(text: string, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.yesNo(text, dialogToKdialog(options))
    end
    return zenity.question(text, nil, nil, dialogToZennity(options))
end

function dialog.yesNoCancel(text: string, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.yesNoCancel(text, dialogToKdialog(options))
    end
    local ops = dialogToZennity(options) or {} :: zenity.ZenityOptions
    ops.extra_buttons = {"Cancel"}
    return zenity.question(text, nil, nil, ops):lower()
end

function dialog.warningYesNo(text: string, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.warningYesNo(text, dialogToKdialog(options))
    end
    local ops = dialogToZennity(options) or {} :: zenity.ZenityOptions
    ops.ok_label = "Yes"
    ops.extra_buttons = {"No"}
    return zenity.warning(text, nil, nil, ops) == "yes"
end

function dialog.warningYesNoCancel(text: string, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.warningYesNoCancel(text, dialogToKdialog(options))
    end
    local ops = dialogToZennity(options) or {} :: zenity.ZenityOptions
    ops.ok_label = "Yes"
    ops.extra_buttons = {"No", "Cancel"}
    return zenity.warning(text, nil, nil, ops):lower()
end

function dialog.warningContinueCancel(text: string, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.warningContinueCancel(text, dialogToKdialog(options))
    end
    local ops = dialogToZennity(options) or {} :: zenity.ZenityOptions
    ops.ok_label = "Continue"
    ops.extra_buttons = {"Cancel"}
    return zenity.warning(text, nil, nil, ops) == "yes"
end

function dialog.warning(text: string, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.sorry(text, dialogToKdialog(options))
    end
    return zenity.warning(text, nil, nil, dialogToZennity(options))
end

function dialog.error(text: string, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.error(text, dialogToKdialog(options))
    end
    return zenity.error(text, nil, nil, dialogToZennity(options))
end

function dialog.info(text: string, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.msgBox(text, dialogToKdialog(options))
    end
    return zenity.info(text, nil, nil, dialogToZennity(options))
end

function dialog.input(text: string, init: string?, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.inputBox(text, init, dialogToKdialog(options))
    end
    return zenity.entry(text, init, nil, dialogToZennity(options))
end

function dialog.password(text: string, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.password(text, dialogToKdialog(options))
    end
    return zenity.password(nil, dialogToZennity(options))
end

function dialog.newPassword(text: string, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.newPassword(text, dialogToKdialog(options))
    end
    local opts = dialogToZennity(options) or {} :: zenity.ZenityOptions
    local formEntries = {
        {type = "password", name = "New Password"},
        {type = "password", name = "Confirm"}
    }
    local formOptions = {text = "Enter a New Password"}
    local out
    repeat
        out = zenity.form(formEntries, formOptions, opts)
        if out then
            local left, right = table.unpack(out:split("|"))
            if left == right then
                break
            else
                formOptions.text = "Passwords did not match"
            end
        end
    until out == nil
    if out then
        return select(-1, table.unpack(out:split("|")))
    end
    return nil
end

function dialog.textBox(file_path: string, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.textBox(file_path, dialogToKdialog(options))
    end
    return zenity.textInfo({
        editable = false,
        filename = file_path
    }, dialogToZennity(options))
end

function dialog.textBoxInput(text: string, init: string?, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.textInputBox(text, init, dialogToKdialog(options))
    end
    local opts = dialogToZennity(options) or {} :: zenity.ZenityOptions
    if not opts.title then
        opts.title = text
    end
    return zenity.textInfo({
        editable = true
    }, opts)
end

function dialog.combo(text: string, items: {string}, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.comboBox(text, items, nil, dialogToKdialog(options))
    end
    return zenity.form({{
        type = "combo",
        name = text,
        values = items
    }})
end

function dialog.menu(text: string, items: {string}, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.menu(text, items, nil, dialogToKdialog(options))
    end
    local entries = {}
    for _, item in pairs(items) do
        table.insert(entries, {"", item})
    end
    return zenity.list(text, "radiolist", {"", ""}, entries, {
        hidden_columns = {[1] = true}, hide_header=true
    }, dialogToZennity(options))
end

--- Follows zenity convention of `|` separated list of strings
function dialog.checklist(text: string, items: {string}, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        local indices = kdialog.checklist(text, items, {}, dialogToKdialog(options))
        if not indices then return nil end
        local result = {}
        for index in indices do
            table.insert(result, items[index])
        end
        return table.concat(result, "|")
    end
    local entries = {}
    for _, item in pairs(items) do
        table.insert(entries, {"", item})
    end
    return zenity.list(text, "checklist", {"", ""}, entries, {hide_header=true}, dialogToZennity(options))
end

--- Immediately sends a passive notification;
--- prefer `notify-send` for more functionality.
--- Timeout does nothing through zenity.
function dialog.passiveNotification(text: string, timeout: number, icon:  string?, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.passivePopup(text, timeout, icon :: kdialog.KDialogPopupIcon?, dialogToKdialog(options))
    end
    local opts = options or {} :: zenity.ZenityOptions
    if not opts.timeout then
        opts.timeout = 0
    end
    return zenity.notification(text, icon, opts)
end

type DialogGetOptions = {
    multiple:   boolean?,
    directory:  boolean?,
    save:       boolean?,
    separator:  string?,
}

--- `multiple` is mutually exclusive with `directory` and `save`; will error if set to true when
--- either of those are true as well.
function dialog.fileSelection(startDir: string, filter: {string}?, get_options: DialogGetOptions?, options: DialogOptions?)
    if get_options then
        assert(
            not ((get_options.save or get_options.directory) and get_options.multiple),
            "`multiple` is mutually exclusive with `save` and `directory."
        )
    end
    if PREFERRED_INTERFACE == "kdialog" then
        local opts = dialogToKdialog(options) or {}
        if get_options and get_options.save then
            return kdialog.getSaveFilename(startDir, filter, opts)
        elseif get_options and get_options.directory then
            return kdialog.getExistingDirectory(startDir, opts)
        end
        if get_options and get_options.separator then
            opts.separator = get_options.separator
        end
        return kdialog.getOpenFilename(startDir, filter, get_options and get_options.multiple, opts)
    end
    return zenity.fileSelection(startDir, filter, get_options, dialogToZennity(options))
end

local DialogProgressBar = {}
DialogProgressBar.__index = DialogProgressBar
function DialogProgressBar:SetLabelText(text: string)
    self.inner:SetLabelText(text)
end
function DialogProgressBar:SetProgress(n: number)
    if self.type == "zenity" then
        self.inner:SetProgress(math.floor(n / self.size * 100))
    else
        self.inner:SetProgress(n)
    end
end
function DialogProgressBar:GetProgress() : number
    return self.progress
end
function DialogProgressBar:Close()
    self.inner:Close()
end

--- Do note a very important distinction in behavior between `zenity` and `kdialog`.
--- `kdialog`'s progress bar will not prevent the program from ending if it is still open
--- when runtime ends, as it is a completely separate process.
--- On the other hand, `zenity`'s progress bar will keep the program
--- alive if left alone, and as such, strongly advise setting
--- `autoclose` to true, and make sure to manually invoke :Close when
--- you are done working with it.
--- Additionally, all `zenity` progress bars scale from 0 to 100; the unified interface
--- divides values given to :SetProgress by the initially given size and rounds down
--- when setting the value of `zenity`'s progress bar.
function dialog.progressBar(initial_text: string, size: number, autoclose: boolean?, options: DialogOptions?)
    local inner = if PREFERRED_INTERFACE == "kdialog" then
            kdialog.progressBar(initial_text, size, autoclose, dialogToKdialog(options))
        else
            zenity.progress(initial_text, 0, {auto_close=autoclose}, dialogToZennity(options))
    local interface = {
        type = PREFERRED_INTERFACE,
        inner = inner,
        size = size,
        progress = 0
    }
    
    return setmetatable(interface, DialogProgressBar)
end
export type DialogProgressBar = typeof(dialog.progressBar("", 100, true))

--- Unlike using `kdialog` or `zenity` directly, simply returns
--- the RGB triple as a tuple of the three numbers.
--- Expected input and outputs are in the range 0-255.
--- Errors if size of `default` is not 3.
function dialog.color(default: {number}?, options: DialogOptions?)
    assert(not default or #default == 3, "default is expected to have size 3")
    if PREFERRED_INTERFACE == "kdialog" then
        local initial = if default then ("#%2X%2X%2X"):format(table.unpack(default)):gsub(" ", "0") else nil
        local out = kdialog.getColor("%d %d %d", initial, dialogToKdialog(options))
        if out then
            local r, g, b = table.unpack(out:split(" "))
            return tonumber(r), tonumber(g), tonumber(b)
        end
        return nil
    end
    local out = zenity.colorSelection(
        if default then `rgb({default[1]},{default[2]},{default[3]})` else nil,
        false,
        dialogToZennity(options)
    )
    if out then
        local r, g, b = out:match("rgb%((%d+),(%d+),(%d+)%)")
        return tonumber(r), tonumber(g), tonumber(b)
    end
    return nil
end

function dialog.slider(text: string, min: number, max: number, step: number, options: DialogOptions?)
    if PREFERRED_INTERFACE == "kdialog" then
        return kdialog.slider(text, min, max, step, dialogToKdialog(options))
    end
    return zenity.scale(text, min, max, step, math.floor(min / max), dialogToZennity(options))
end

function dialog.calendar(text: string, options: DialogOptions?) : DateTime.DateTime?
    local out = if PREFERRED_INTERFACE == "kdialog" then
            kdialog.calendar(text, "dd MM yyyy", dialogToKdialog(options))
        else
            zenity.calendar(text, nil, nil, nil, "%d %m %Y")

    if out then
        local day, month, year = out:match("(%d+) (%d+) (%d+)")
        return DateTime.fromLocalTime({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = 0, minute = 0, second = 0
        })
    end
    return nil
end

return dialog