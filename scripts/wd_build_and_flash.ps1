# WD Build and Flash Script
# Target: Windows 11 with Docker Desktop or WSL2 Docker

Write-Host "Starting OpenBSD Kernel cross-compile build on WD..."

# Build the docker container
Write-Host "Building Docker Image..."
docker build -t openbsd-builder ../docker

# Run the docker container
Write-Host "Running Docker Container..."
$srcDir = Resolve-Path "..\src\sys"
$outDir = Resolve-Path "..\out"

# Ensure out directory exists
if (-not (Test-Path -Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir
}

docker run --rm -it -v "$($srcDir):/src" -v "$($outDir):/out" openbsd-builder

Write-Host "Build finished. Check ../out/bsd"
