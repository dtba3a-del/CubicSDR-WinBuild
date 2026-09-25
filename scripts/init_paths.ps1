
$CS_ROOT=(get-location).path -replace '\\', '/'
Write-Host "Initializing Paths under $CS_ROOT.."

$BUILD_ROOT="$CS_ROOT/build-$CS_BUILD_ARCH-$CS_BUILD_TYPE"
New-Item -ItemType Directory -Path $BUILD_ROOT -Force | Out-Null
Write-Host "`tBuild Path: $BUILD_ROOT"

$CS_SOURCES="$BUILD_ROOT/sources"
New-Item -ItemType Directory -Path $CS_SOURCES -Force | Out-Null
Write-Host "`tSources Path: $CS_SOURCES"

$CS_TARGET="$BUILD_ROOT/target"
New-Item -ItemType Directory -Path $CS_TARGET -Force | Out-Null
Write-Host "`tTarget Path: $CS_TARGET"

$CS_INSTALL="$BUILD_ROOT/install"
New-Item -ItemType Directory -Path $CS_INSTALL -Force | Out-Null

$CS_DEPS="$BUILD_ROOT/dependencies"
New-Item -ItemType Directory -Path $CS_DEPS -Force | Out-Null
Write-Host "`tDependencies Path: $CS_DEPS"

$SZ_PATH=(Get-ChildItem -Path "C:\Program Files" -Filter "7z.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1).DirectoryName
if (-not ($SZ_PATH | Test-Path)) {
    $SZ_PATH=(Get-ChildItem -Path "C:\Program Files (x86)" -Filter "7z.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1).DirectoryName
}
$SZ_CMD="$SZ_PATH\7z.exe"
Write-Host "`t7-Zip Path: $SZ_CMD"
# Upstream module repos are cloned at the last commit before this date, so the
# build scripts keep working as those projects change (override with CS_PIN_DATE).
$CS_PIN_DATE = if ($env:CS_PIN_DATE) { $env:CS_PIN_DATE } else { "2024-04-12" }
Write-Host "`tSource pin date: $CS_PIN_DATE"
function Get-PinnedSource([string]$url, [string]$dir) {
    git clone --filter=blob:none $url $dir
    $rev = git -C $dir rev-list -1 --before="$CS_PIN_DATE" HEAD
    if ($rev) { git -C $dir -c advice.detachedHead=false checkout $rev }
}

# Current MSVC STL no longer pulls <chrono> in transitively; older upstream
# sources that rely on it get the include prepended (C++ files only).
function Add-MissingInclude([string]$dir, [string]$pattern, [string]$include) {
    Get-ChildItem -Path $dir -Recurse -File -Include *.cpp,*.cc,*.hpp,*.h |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
        ForEach-Object {
            $text = [IO.File]::ReadAllText($_.FullName)
            if ($text -match $pattern -and -not $text.Contains($include)) {
                [IO.File]::WriteAllText($_.FullName, "$include`n$text")
            }
        }
}
