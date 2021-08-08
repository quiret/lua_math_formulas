local pi = math.pi;
local pi_half = pi / 2;

-- Optimizations.
local error = error;
local debug = debug;
local outputDebugString = outputDebugString;

function traceback()
    local level = debug.getinfo(1);
    local n = 1;
    
    while (level) do
        outputDebugString(level.short_src .. ": " .. level.currentline .. ", " .. level.linedefined);
        
        n = n + 1;
        level = debug.getinfo(n);
    end
    
    error("traceback!", 2);
end

function assert_traceback(cond)
    if not (cond) then
        traceback();
    end
end