# Usage: scoop status
# Summary: Show status and check for new app versions
# Options:
#   -q, --quiet               Hide extraneous messages

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\git.ps1"

reset_aliases

$opt, $apps, $err = getopt $args 'q' 'quiet'
if($err) { "scoop status: $err"; exit 1 }
$quiet = $opt.q -or $opt.quiet

# check if scoop needs updating
$currentdir = fullpath $(versiondir 'scoop' 'current')
$needs_update = $false

if(test-path "$currentdir\.git") {
    Push-Location $currentdir
    git_fetch -q origin
    $commits = $(git log "HEAD..origin/$(scoop config SCOOP_BRANCH)" --oneline)
    if($commits) { $needs_update = $true }
    Pop-Location
}
else {
    $needs_update = $true
}

if($needs_update -and !$quiet) {
    warn "Scoop is out of date. Run 'scoop update' to get the latest changes."
}
elseif(!$quiet) { success "Scoop is up to date."}

$failed = @()
$outdated = @()
$removed = @()
$missing_deps = @()
$onhold = @()

$true, $false | ForEach-Object { # local and global apps
    $global = $_
    $dir = appsdir $global
    if(!(test-path $dir)) { return }

    Get-ChildItem $dir | Where-Object name -ne 'scoop' | ForEach-Object {
        $app = $_.name
        $status = app_status $app $global
        if($status.failed) {
            $failed += @{ $app = $status.version }
        }
        if($status.removed) {
            $removed += @{ $app = $status.version }
        }
        if($status.outdated) {
            $outdated += @{ $app = @($status.version, $status.latest_version) }
            if($status.hold) {
                $onhold += @{ $app = @($status.version, $status.latest_version) }
            }
        }
        if($status.missing_deps) {
            $missing_deps += ,(@($app) + @($status.missing_deps))
        }
    }
}

if($outdated) {
    if(!$quiet) { write-host -f DarkCyan 'Updates are available for:' }
    $outdated.keys | ForEach-Object {
        $versions = $outdated.$_
        "    $_`: $($versions[0]) -> $($versions[1])"
    }
}

if($onhold) {
    if(!$quiet) { write-host -f DarkCyan 'These apps are outdated and on hold:' }
    $onhold.keys | ForEach-Object {
        $versions = $onhold.$_
        "    $_`: $($versions[0]) -> $($versions[1])"
    }
}

if($removed) {
    if(!$quiet) { write-host -f DarkCyan 'These app manifests have been removed:' }
    $removed.keys | ForEach-Object {
        "    $_"
    }
}

if($failed) {
    if(!$quiet) { write-host -f DarkCyan 'These apps failed to install:' }
    $failed.keys | ForEach-Object {
        "    $_"
    }
}

if($missing_deps) {
    if(!$quiet) { write-host -f DarkCyan 'Missing runtime dependencies:' }
    $missing_deps | ForEach-Object {
        $app, $deps = $_
        "    '$app' requires '$([string]::join("', '", $deps))'"
    }
}

if(!$old -and !$removed -and !$failed -and !$missing_deps -and !$needs_update -and !$quiet) {
    success "Everything is ok!"
}

exit 0
