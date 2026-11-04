local BackupHealth = {}

function BackupHealth:getStatus()
    return {
        code = "UNKNOWN",
        label = "UNKNOWN",
        path = nil,
        age_days = nil,
        is_new = false,
    }
end

function BackupHealth:markSynced(path)
end

return BackupHealth
