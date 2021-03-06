#Requires -Version 3.0

Param(
 [Parameter(Mandatory=$True)]
 [string]
 $EnvironmentTag,

 [string]
 $VersionTag = "latest"
)

# stop the script on first error
$ErrorActionPreference = 'Stop'

#******************************************************************************
# Functions
#******************************************************************************

Function Build-Container([string]$ContainerTag, [string]$BuildContextFolderName, [string]$RegistryUrl) {
    Write-Host "`r`n[BUILD CONTAINER] Building $ContainerTag container..." -foreground "green"

    $buildContext = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $BuildContextFolderName))
    $dockerfile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "$BuildContextFolderName/Dockerfile"))

    docker build -t $ContainerTag -f $dockerfile $buildContext

    if ($LastExitCode -ne 0) {
        throw "Could not build the image $ContainerTag from file: $dockerfile for context: $buildContext"
    }

    docker tag $ContainerTag $registryUrl/$ContainerTag

    if ($LastExitCode -ne 0) {
        throw "Could not tag the image $ContainerTag for $registryUrl/$ContainerTag"
    }

    Write-Host "[PUSH TO REPOSITORY] Pushing $ContainerTag container to $RegistryUrl..." -foreground "green"

    docker push $RegistryUrl/$ContainerTag

    if ($LastExitCode -ne 0) {
        throw "Could not push the image $RegistryUrl/$ContainerTag"
    }


    Write-Host "[FINISHED] Finished building $ContainerTag container" -foreground "green"
}

#******************************************************************************
# Script body
#******************************************************************************

Write-Host "Logging in into the Azure Container Registry..."

$keyVaultName = "ca-devcache-$EnvironmentTag"

$registryUsername = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -SecretName registryAdminUsername).SecretValueText
$registryPassword = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -SecretName registryAdminPassword).SecretValueText

$registryUrl = ("cadevcache" + $EnvironmentTag + "registry.azurecr.io")

docker login $registryUrl -u $registryUsername -p $registryPassword

if ($LastExitCode -ne 0) {
    throw "Could not login to the docker registry"
}

Build-Container -ContainerTag "devicecache-frontend:$VersionTag" -BuildContextFolderName "DeviceCache.Frontend" -RegistryUrl $registryUrl
Build-Container -ContainerTag "devicecache-processor:$VersionTag" -BuildContextFolderName "DeviceCache.Processor" -RegistryUrl $registryUrl
Build-Container -ContainerTag "devicecache-simulator:$VersionTag" -BuildContextFolderName "DeviceCache.Simulator" -RegistryUrl $registryUrl