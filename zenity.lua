local process = require "@lune/process"
local task = require "@lune/task"
local fs = require "@lune/fs"
local shared = require "@self/shared"

--[=[
    Lune module for working with zenity.
]=]
local zenity = {}

export type ZenityOptions = {
    title: string?,
    width: number?,
    height: number?,
    timeout: number?,
    ok_label: string?,
    cancel_label: string?,
    extra_buttons: { string }?,
    modal: string?,
}

local clean = shared.clean
local replaceHome = shared.replaceHome

local function zenityPushOptions(command: { string }, options: ZenityOptions)
    for option, value in pairs(options) do
        if option == "extra_buttons" then
            for _, text in ipairs(value) do
                table.insert(command, "--extra-button")
                table.insert(command, text)
            end
        elseif option:match("_") then
            table.insert(command, `--{option:gsub("_", "-")}`)
            table.insert(command, `{value}`)
        else
            table.insert(command, `--{option}`)
            table.insert(command, `{value}`)
        end
    end
end

local function zenityExecute(command: { string }, options: ZenityOptions?, procOptions: process.ExecOptions?)
    if options ~= nil then
        zenityPushOptions(command, options)
    end

    local result = process.exec("zenity", command, procOptions)

    return result
end

-- `format` defaults to "MM/DD/YYYY" (unless that's a system localization thing lol)
function zenity.calendar(
    text: string,
    day: number?,
    month: number?,
    year: number?,
    format: string?,
    options: ZenityOptions?
): string?
    local args = { "--calendar", text }
    for option, val in { ["--day"] = day, ["--month"] = month, ["--year"] = year } do
        if val then
            table.insert(args, `{option}={val}`)
        end
    end
    if format then
        table.insert(args, "--date-format")
        table.insert(args, format)
    end

    local out = zenityExecute(args, options)
    if out.code ~= 0 then
        return nil
    end
    return clean(out.stdout)
end

function zenity.entry(text: string, init: string?, hide: boolean?, options: ZenityOptions?): string?
    local args = { "--entry", "--text", text }
    if init then
        table.insert(args, "--entry-text")
        table.insert(args, init)
    end
    if hide then
        table.insert(args, "--hide-text")
    end

    local out = zenityExecute(args, options)
    if out.code ~= 0 then
        return nil
    end
    return clean(out.stdout)
end

function zenityTextInfoBox(
    command: string,
    text: string,
    icon: string?,
    info_options: { no_wrap: boolean, no_markup: boolean, ellipsize: boolean }?,
    options: ZenityOptions?
)
    local args = { command, "--text", text }
    if icon then
        table.insert(args, "--icon")
        table.insert(args, icon)
    end
    if info_options then
        for option in pairs(info_options) do
            table.insert(args, `--{option:gsub("_", "-")}`)
        end
    end

    if options and options.extra_buttons then
        local out = zenityExecute(args, options)
        if out.code == 0 then
            return "yes"
        elseif out.stdout == "" then
            return "no"
        else
            return clean(out.stdout)
        end
    end
    return zenityExecute(args, options).code == 0
end

function zenity.error(
    text: string,
    icon: string?,
    info_options: { no_wrap: boolean, no_markup: boolean, ellipsize: boolean }?,
    options: ZenityOptions?
)
    return zenityTextInfoBox("--error", text, icon, info_options, options)
end

function zenity.info(
    text: string,
    icon: string?,
    info_options: { no_wrap: boolean, no_markup: boolean, ellipsize: boolean }?,
    options: ZenityOptions?
)
    return zenityTextInfoBox("--info", text, icon, info_options, options)
end

function zenity.warning(
    text: string,
    icon: string?,
    info_options: { no_wrap: boolean, no_markup: boolean, ellipsize: boolean }?,
    options: ZenityOptions?
)
    return zenityTextInfoBox("--warning", text, icon, info_options, options)
end

--- Returns `true` if user selected "Ok" button
function zenity.question(
    text: string,
    icon: string?,
    info_options: { no_wrap: boolean, no_markup: boolean, ellipsize: boolean }?,
    options: ZenityOptions?
)
    return zenityTextInfoBox("--question", text, icon, info_options, options)
end

function zenity.fileSelection(
    default: string?,
    filter: { string }?,
    selection_options: { multiple: boolean?, directory: boolean?, save: boolean?, separator: string? }?,
    options: ZenityOptions?
): string?
    local args = { "--file-selection" }
    if default then
        table.insert(args, "--filename")
        table.insert(args, replaceHome(default))
    end
    if filter then
        for _i, filter in ipairs(filter) do
            table.insert(args, "--file-filter")
            table.insert(args, filter)
        end
    end
    if selection_options then
        for option, value in selection_options do
            if value then
                table.insert(args, `--{option}`)
                if type(value) == "string" then
                    table.insert(args, value)
                end
            end
        end
    end

    local out = zenityExecute(args, options)
    if out.code ~= 0 then
        return nil
    end
    return clean(out.stdout)
end

type ZenityListOptions = {
    editable: boolean?,
    multiple: boolean?,
    hide_header: boolean?,
    separator: string?,
    hidden_columns: { [number]: boolean }?,
}
--[=[
    `list_type` determines the button used for the first column. `entries` is expected to be a list of lists that have the same size as `headers`.
]=]
function zenity.list(
    text: string,
    list_type: "checklist" | "radiolist" | "imagelist",
    headers: { string },
    entries: { { string } },
    list_options: ZenityListOptions?,
    options: ZenityOptions?
): string?
    local args = { "--list", "--text", text, `--{list_type}` }
    for _, header in ipairs(headers) do
        table.insert(args, "--column")
        table.insert(args, header)
    end
    for _, list in ipairs(entries) do
        for _, entry in ipairs(list) do
            table.insert(args, entry)
        end
    end

    if list_options then
        for option, value in pairs(list_options) do
            if option == "hidden_columns" then
                for number in value :: { [number]: boolean } do
                    table.insert(args, "--hide-column")
                    table.insert(args, tostring(number))
                end
            elseif option == "separator" then
                table.insert(args, "--separator")
                table.insert(args, value)
            else
                table.insert(args, `--{option:gsub("_", "-")}`)
            end
        end
    end

    local out = zenityExecute(args, options)
    if out.code ~= 0 then
        return nil
    end
    return clean(out.stdout)
end

--- The `listen` option is unsupported due to the difficulty of writing to the process' `stdin`.
--- Immediately sends notification and returns nothing. Prefer `notify-send` for more functionality.
function zenity.notification(text: string, icon: string?, options: ZenityOptions?)
    local args = { "--notification", "--text", text }
    if icon then
        table.insert(args, "--icon")
        table.insert(args, icon)
    end

    zenityExecute(args, options)
end

type ZenityProgressOptions = {
    pulsate: boolean?,
    auto_close: boolean?,
    auto_kill: boolean?,
    no_cancel: boolean?,
    time_remaining: boolean?,
}

--- Wrapper around some bash scripts that manages and interacts with
--- a zenity progress bar.
local ZenityProgressBar = {}
ZenityProgressBar.__index = ZenityProgressBar
function ZenityProgressBar.new(
    start_percentage: number,
    progress_options: ZenityProgressOptions?,
    options: ZenityOptions?
)
    local pipePath = clean(process.exec("mktemp", { "-u" }).stdout)
    local pipeOut = clean(process.exec("mktemp", { "-u" }).stdout)
    local command = { "zenity", "--progress" }
    if progress_options then
        for option, value in progress_options do
            if value then
                table.insert(command, ` --{option:gsub("_", "-")}`)
            end
        end
    end
    if options then
        zenityPushOptions(command, options)
    end
    process.exec("mkfifo", { pipePath })
    process.exec("mkfifo", { pipeOut })
    local bashScript = ([=[#!/bin/bash
        (while [[ $n -lt 100 ]]
        do
            input=$(cat %s)
            if [ -n "$input" ] && [ "$input" -eq "$input" ] 2>/dev/null; then
                n=$input
            fi
            echo $input
        done) | %s
        
        echo "dead" > %s]=]):format(pipePath, table.concat(command, " "), pipeOut)

    task.spawn(function()
        process.exec("bash", { "-c", bashScript })
    end)

    local progressBar = {
        pipe = pipePath,
        progress = options,
        alive = true,
    }

    task.defer(function()
        fs.readFile(pipeOut)
        progressBar.alive = false
        fs.removeFile(pipePath)
        fs.removeFile(pipeOut)
    end)

    return setmetatable(progressBar, ZenityProgressBar)
end
type ZenityProgressBar = typeof(ZenityProgressBar.new(0))
function ZenityProgressBar:SetLabelText(text: string)
    if not self.alive then
        return
    end
    process.exec("bash", { "-c", `echo "# {text}" > {self.pipe}` })
end
function ZenityProgressBar:SetProgress(n: number)
    self.progress = n
    if not self.alive then
        return
    end
    self.alive = n < 100
    process.exec("bash", { "-c", `echo "{n}" > {self.pipe}` })
end
function ZenityProgressBar:GetProgress(): number
    return self.progress
end
function ZenityProgressBar:Close()
    if not self.alive then
        return
    end
    process.exec("bash", { "-c", `echo "100" > {self.pipe}` })
end

function zenity.progress(
    text: string,
    start_percentage: number?,
    progress_options: ZenityProgressOptions?,
    options: ZenityOptions?
)
    return ZenityProgressBar.new(start_percentage or 0, progress_options, options)
end

function zenity.scale(
    text: string,
    min: number,
    max: number,
    step: number,
    default: number?,
    options: ZenityOptions?
): number?
    local args = {
        "--scale",
        "--text",
        text,
        "--min-value",
        tostring(min),
        "--max-value",
        tostring(max),
        "--step",
        tostring(step),
    }
    if default then
        table.insert(args, "--value")
        table.insert(args, tostring(default))
    end
    local out = zenityExecute(args, options)
    if out.code ~= 0 then
        return nil
    end
    return tonumber(out.stdout:match("%d+"))
end

function zenity.textInfo(
    info_options: {
        filename: string?,
        editable: boolean?,
        font: string?,
        checkbox: string?,
        auto_scroll: string?,
    }?,
    options: ZenityOptions?
): string?
    local args = { "--text-info" }
    if info_options then
        for option, val in pairs(info_options) do
            if val then
                table.insert(args, `--{option:gsub("_", "-")}`)
                if type(val) == "string" then
                    table.insert(args, val)
                end
            end
        end
    end

    local out = zenityExecute(args, options)
    if out.code ~= 0 then
        return nil
    end
    return clean(out.stdout)
end

--- Returns color in the form "rgb(RRR,GGG,BBB)"
function zenity.colorSelection(color: string?, show_palette: boolean?, options: ZenityOptions?): string?
    local args = { "--color-selection" }
    if color then
        table.insert(args, "--color")
        table.insert(args, color)
    end
    if show_palette then
        table.insert(args, "--show-palette")
    end

    local out = zenityExecute(args, options)
    if out.code ~= 0 then
        return nil
    end
    return clean(out.stdout)
end

--- Returns `"user|pass"` if `prompt_user` is enabled; otherwise only returns `pass`
function zenity.password(propt_user: boolean?, options: ZenityOptions?)
    local out = zenityExecute({ "--password", if propt_user then "--username" else "" }, options)
    if out.code ~= 0 then
        return nil
    end
    return clean(out.stdout)
end

type ZenityFormEntry = {
    type: "entry" | "password" | "calendar",
    name: string,
} | {
    type: "list" | "combo",
    name: string,
    values: { string },
}
type ZenityFormOptions = {
    text: string?,
    separator: string?,
    date_format: string?,
    show_header: string?,
}

--- Separator defaults to `|`.
function zenity.form(entries: { ZenityFormEntry }, form_options: ZenityFormOptions?, options: ZenityOptions?): string?
    local args = { "--forms" }
    for i, entry in ipairs(entries) do
        if entry.type == "entry" or entry.type == "password" or entry.type == "calendar" then
            table.insert(args, `--add-{entry.type}`)
            table.insert(args, entry.name)
        elseif entry.type == "list" or entry.type == "combo" then
            table.insert(args, `--add-{entry.type}`)
            table.insert(args, entry.name)
            table.insert(args, `--{entry.type}-values`)
            table.insert(args, table.concat(entry.values, "|"))
        end
    end

    if form_options then
        for option, val in form_options do
            table.insert(args, `--{option:gsub("_", "-")}`)
            table.insert(args, val)
        end
    end

    local out = zenityExecute(args, options)
    if out.code ~= 0 then
        return nil
    end
    return clean(out.stdout)
end

return zenity
