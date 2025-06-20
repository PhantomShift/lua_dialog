local process = require "@lune/process"

return {
    replaceHome = function(path: string)
        local r = path:gsub("^~", process.env.HOME)
        return r
    end,

    clean = function(s: string)
        return s:match("^(.-)\n*$") :: string
    end,
}
