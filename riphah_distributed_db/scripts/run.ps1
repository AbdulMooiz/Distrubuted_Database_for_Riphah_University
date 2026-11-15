param(
    [ValidateSet('up','seed','verify','a','b','c','d','e','semijoin','transfer','all','down','reset')]
    [string]$Task = 'all'
)
$ErrorActionPreference = 'Stop'
function Invoke-Docker([string[]]$CommandArgs) {
    & docker @CommandArgs
    if ($LASTEXITCODE -ne 0) { throw "Docker command failed: docker $($CommandArgs -join ' ')" }
}
function Invoke-Sql([string]$Service, [string]$File, [bool]$StopOnError = $true) {
    $commandArgs = @('compose','exec','-T',$Service,'psql','-U','postgres','-d','riphah')
    if ($StopOnError) { $commandArgs += @('-v','ON_ERROR_STOP=1') }
    $commandArgs += @('-f',"/project/$File")
    & docker @commandArgs
    if ($LASTEXITCODE -ne 0) { throw "SQL script failed: $File on $Service" }
}
function Invoke-Analyze {
    foreach ($service in @('main','lahore','faisalabad')) {
        Invoke-Docker @('compose','exec','-T',$service,'psql','-U','postgres','-d','riphah','-c','ANALYZE;')
    }
}
switch ($Task) {
    'up' { Invoke-Docker @('compose','up','-d','--wait') }
    'seed' { Invoke-Sql 'main' 'sql/10_seed_and_distribute.sql'; Invoke-Analyze }
    'verify' { Invoke-Sql 'main' 'sql/20_verify.sql' }
    'a' { Invoke-Sql 'faisalabad' 'sql/demo/a_horizontal.sql' }
    'b' { Invoke-Sql 'lahore' 'sql/demo/b_vertical_security.sql'; Invoke-Sql 'main' 'sql/demo/b_view_comparison.sql' }
    'c' { Invoke-Sql 'main' 'sql/demo/c_status_trap.sql' }
    'd' { Invoke-Sql 'main' 'sql/demo/d_allocation_replication.sql' }
    'e' { Invoke-Sql 'lahore' 'sql/demo/e_queries_lahore.sql'; Invoke-Sql 'faisalabad' 'sql/demo/e_queries_faisalabad.sql'; Invoke-Sql 'main' 'sql/demo/e_queries_main.sql' }
    'semijoin' { Invoke-Sql 'faisalabad' 'sql/demo/e_semijoin.sql' }
    'transfer' { Invoke-Sql 'main' 'sql/demo/f_transfer_procedure.sql'; Invoke-Sql 'main' 'sql/demo/f_transfer.sql' }
    'all' {
        Invoke-Docker @('compose','up','-d','--wait')
        Invoke-Sql 'main' 'sql/10_seed_and_distribute.sql'
        Invoke-Analyze
        Invoke-Sql 'main' 'sql/20_verify.sql'
        Invoke-Sql 'faisalabad' 'sql/demo/a_horizontal.sql'
        Invoke-Sql 'lahore' 'sql/demo/b_vertical_security.sql'
        Invoke-Sql 'main' 'sql/demo/b_view_comparison.sql'
        Invoke-Sql 'main' 'sql/demo/c_status_trap.sql'
        Invoke-Sql 'main' 'sql/demo/d_allocation_replication.sql'
        Invoke-Sql 'lahore' 'sql/demo/e_queries_lahore.sql'
        Invoke-Sql 'faisalabad' 'sql/demo/e_queries_faisalabad.sql'
        Invoke-Sql 'main' 'sql/demo/e_queries_main.sql'
        Invoke-Sql 'faisalabad' 'sql/demo/e_semijoin.sql'
        Invoke-Sql 'main' 'sql/demo/f_transfer_procedure.sql'
        Invoke-Sql 'main' 'sql/demo/f_transfer.sql'
    }
    'down' { Invoke-Docker @('compose','down') }
    'reset' { Invoke-Docker @('compose','down','-v') }
}
