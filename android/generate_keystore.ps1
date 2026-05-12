# Generate a self-signed release keystore and key.properties for Flutter Android builds
# Run this script once before building a release APK/AAB.

$keyPropsPath = Join-Path $PSScriptRoot "key.properties"
$keystorePath = Join-Path $PSScriptRoot "release-keystore.jks"

if (Test-Path $keyPropsPath) {
    Write-Host "key.properties already exists at $keyPropsPath"
    Write-Host "Delete it first if you want to regenerate."
    exit 0
}

$alias = "securescan-release"
$validity = 10000

Write-Host "Generating release keystore..."
# Use keytool from Java runtime (bundled with Android Studio / Flutter)
$keytool = Get-Command "keytool" -ErrorAction SilentlyContinue
if (-not $keytool) {
    Write-Host "ERROR: keytool not found. Ensure Java is installed and in PATH."
    exit 1
}

$storePass = -join ((0x30..0x39) + (0x41..0x5A) + (0x61..0x7A) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
$keyPass = $storePass

& keytool -genkey -v `
    -keystore "$keystorePath" `
    -alias "$alias" `
    -keyalg RSA `
    -keysize 2048 `
    -validity $validity `
    -storepass "$storePass" `
    -keypass "$keyPass" `
    -dname "CN=SecureScan, OU=Development, O=SecureScan, L=Unknown, ST=Unknown, C=US"

if (-not (Test-Path $keystorePath)) {
    Write-Host "ERROR: Keystore generation failed."
    exit 1
}

$props = @"
storeFile=$keystorePath
storePassword=$storePass
keyAlias=$alias
keyPassword=$keyPass
"@

Set-Content -Path $keyPropsPath -Value $props -Encoding ASCII

Write-Host "SUCCESS: Release keystore created at:"
Write-Host "  $keystorePath"
Write-Host "  $keyPropsPath"
Write-Host ""
Write-Host "These files are gitignored. Keep them secure and backed up."
