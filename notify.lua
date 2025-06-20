local process = require "@lune/process"

do
    local stdio = require "@lune/stdio"
    local function findBinary(name: string) : boolean
        local result = process.exec("whereis", {name})
        if not result.ok then return false end
        local path = result.stdout:gsub(`^{name}:`, "")
        return not (path == "")
    end
    if not findBinary("notify-send") then
        stdio.ewrite("[WARNING] Unable to find notify-send binary; dialog.notify will not function as expected")
    end
end

export type NotificationOptions = {
    urgency: "low" | "normal" | "critical"?,
    expire_time: number?,
    icon: string?,
    category: string | {string}?,
    transient: boolean?,
    wait: boolean?,
    actions: {string}?
}

--- Wrapper around `notify-send` for convenient
--- and useful functionality around notifications.
--- Returns `0` if the notification is closed or expires,
--- otherwise returns the index of the button pressed.
return function(title: string, summary: string, body: string?, options: NotificationOptions?)
    local arguments = {
        "--app-name", title
    }
    if options then
        for option, value in pairs(options) do
            if option == "actions" then
                for i, action in ipairs(value) do
                    table.insert(arguments, "--action")
                    table.insert(arguments, `{i}={action}`)
                    -- table.insert(arguments, action)
                end
            elseif type(value) == "boolean" and value then
                table.insert(arguments, `--{option:gsub("_", "-")}`)
            elseif type(value) == "table" then
                table.insert(arguments, `--{option:gsub("_", "-")}`)
                table.insert(arguments, table.concat(value, ","))
            else
                table.insert(arguments, `--{option:gsub("_", "-")}`)
                table.insert(arguments, value)
            end
        end
    end
    table.insert(arguments, summary)
    if body then
        table.insert(arguments, body)
    end

    local out = process.exec("notify-send", arguments)
    if out.stdout == "" then return 0 end
    return tonumber(out.stdout:match("%d+"))
end