$ErrorActionPreference = 'Stop'
$network = 'riphah_ddb_default'
$container = 'riphah_faisalabad'
$disconnected = $false
try {
    & docker network disconnect $network $container
    if ($LASTEXITCODE -ne 0) { throw 'Could not disconnect Faisalabad from the Docker network.' }
    $disconnected = $true

    Write-Host "=== Faisalabad isolated: local queries and expected remote failures ==="
    & docker compose exec -T faisalabad psql -U postgres -d riphah -f /project/sql/demo/f_failure_faisalabad.sql
    Write-Host "=== Main cannot reach Faisalabad replica ==="
    & docker compose exec -T main psql -U postgres -d riphah -f /project/sql/demo/f_failure_main.sql
}
finally {
    if ($disconnected) {
        Write-Host 'Reconnecting Faisalabad...'
        & docker network connect --alias faisalabad $network $container
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Reconnect failed. Run: docker network connect --alias faisalabad riphah_ddb_default riphah_faisalabad' }
    }
}
