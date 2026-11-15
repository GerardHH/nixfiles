-- Helpers for the specs: a scratch git repository per test, files written
-- with set modification times, and `collect` run inside the repository.
--
-- Times are set, not waited for: whether notes are stale depends on which
-- was written last, a file or the notes file, and setting the times keeps
-- the specs fast and independent of the file system's time resolution.
local helpers = {}

-- Seconds since the epoch the specs count from; any fixed past time works.
helpers.base_time = 1700000000

-- Runs git in `repository_root`, with `stdin_text` on its stdin if given;
-- fails the spec on an error, with git's message.
function helpers.git(repository_root, git_arguments, stdin_text)
    local git_command = { "git", "-C", repository_root }
    vim.list_extend(git_command, git_arguments)
    local git_result = vim.system(git_command, { text = true, stdin = stdin_text }):wait()
    if git_result.code ~= 0 then
        error(("git %s failed: %s"):format(table.concat(git_arguments, " "), git_result.stderr))
    end
    return git_result.stdout
end

-- Writes `file_lines` to `relative_path` in the repository, making its
-- directory, and sets its modification time to base_time + `time_offset`
-- seconds (0 when nil).
function helpers.write(repository_root, relative_path, file_lines, time_offset)
    local file_path = repository_root .. "/" .. relative_path
    vim.fn.mkdir(vim.fs.dirname(file_path), "p")
    vim.fn.writefile(file_lines, file_path)
    local file_time = helpers.base_time + (time_offset or 0)
    assert(vim.uv.fs_utime(file_path, file_time, file_time))
end

-- Makes a repository with `committed_files` (relative path → lines)
-- committed, and returns its root. Identity given inline, as the specs run
-- without a global git config.
function helpers.make_repository(committed_files)
    local repository_root = vim.fn.tempname()
    vim.fn.mkdir(repository_root, "p")
    helpers.git(repository_root, { "init", "--quiet" })
    -- Committed files get an older time than the specs' later writes: git
    -- trusts its index's stat cache, so a rewrite with the same size and time
    -- (`two` → `TWO`) would show no diff at all.
    for relative_path, file_lines in pairs(committed_files) do
        helpers.write(repository_root, relative_path, file_lines, -100)
    end
    helpers.git(repository_root, { "add", "--all" })
    helpers.git(repository_root, {
        "-c",
        "user.name=spec",
        "-c",
        "user.email=spec@example.invalid",
        "commit",
        "--quiet",
        "--message=base",
    })
    return repository_root
end

-- Puts `staged_lines` in the index as the content of `relative_path`,
-- without touching the working tree, as staging a hunk with gitsigns or
-- lazygit does: the working tree file keeps its content and its time.
function helpers.stage(repository_root, relative_path, staged_lines)
    local staged_text = table.concat(staged_lines, "\n") .. "\n"
    local blob_hash = vim.trim(helpers.git(repository_root, { "hash-object", "-w", "--stdin" }, staged_text))
    helpers.git(repository_root, { "update-index", "--cacheinfo", "100644," .. blob_hash .. "," .. relative_path })
end

-- Writes the notes file, by default at base_time + 10 s: after the files the
-- specs write at the default time, as the agent writes it last.
function helpers.write_notes(repository_root, notes_lines, time_offset)
    helpers.write(repository_root, ".agent-notes.md", notes_lines, time_offset or 10)
end

-- Runs `collect` from inside the repository (it finds the repository from
-- the working directory, as the spec's buffer has no file) and returns its
-- result; fails the spec on an error.
function helpers.collect(repository_root)
    vim.fn.chdir(repository_root)
    local changes, collect_error = require("agent_review").collect()
    assert(changes, collect_error)
    return changes
end

-- The entries of `changes` for one path, in line order, each reduced to
-- { lnum, end_lnum, text, stale } so specs compare them as plain tables.
function helpers.entries_of(changes, relative_path)
    local path_entries = {}
    for _, change_entry in ipairs(changes.entries) do
        if change_entry.path == relative_path then
            table.insert(path_entries, {
                lnum = change_entry.lnum,
                end_lnum = change_entry.end_lnum,
                text = change_entry.text,
                stale = change_entry.stale or false,
            })
        end
    end
    table.sort(path_entries, function(left_entry, right_entry) return left_entry.lnum < right_entry.lnum end)
    return path_entries
end

return helpers
