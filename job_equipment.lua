local jobs = {}
local job_list = {
    'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF',
    'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM',
    'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP',
    'DNC', 'SCH', 'GEO', 'RUN'
}

for _, job in ipairs(job_list) do
    local success, job_data = pcall(require, 'jobs.' .. job)
    if success then
        jobs[job] = job_data
    else
        -- If the job file doesn't exist yet, provide an empty structure
        jobs[job] = {
            ARTIFACT = {},
            RELIC = {},
            EMPYREAN = {}
        }
    end
end

return jobs

