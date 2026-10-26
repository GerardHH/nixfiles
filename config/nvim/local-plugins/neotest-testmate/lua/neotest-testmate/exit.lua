-- How a test executable's run ended, from its exit code. Shared by the
-- adapter, for a run without a report, and GTest, for the test a run ended in.
local exit = {}

-- Names of the signals that end a test run most often. neotest reports a
-- process killed by a signal as exit code 128 + the signal's number.
local signals = {
    [4] = "SIGILL",
    [6] = "SIGABRT",
    [7] = "SIGBUS",
    [8] = "SIGFPE",
    [9] = "SIGKILL",
    [11] = "SIGSEGV",
    [15] = "SIGTERM",
}

--- "Crashed: SIGSEGV (exit code 139)" for a run killed by a signal, nil for
--- one that exited.
function exit.crash(code)
    local signal = code - 128
    if signal > 0 and signal < 64 then
        return ("Crashed: %s (exit code %d)"):format(signals[signal] or ("signal " .. signal), code)
    end
    return nil
end

return exit
