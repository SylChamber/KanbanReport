# Kanban Report - fonctions d'aide aux API

function Get-OrgUrl {
<#
.SYNOPSIS
    Obtient l'URL AzureDevOps pour une organisation.
.DESCRIPTION
    Obtient l'URL AzureDevOps pour une organisation.
.PARAMETER Org
    Nom de l'organisation dans Azure DevOps.
.EXAMPLE
    # Obtient l'URL de l'organisation DoD
    Get-OrgUrl -Org DoD
.INPUTS
    System.String
.OUTPUTS
    System.Uri
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Org
    )

    [System.Uri]"https://dev.azure.com/$Org"
}

function Get-ProjectUrl {
<#
.SYNOPSIS
    Obtient l'URL d'un projet dans Azure DevOps.
.DESCRIPTION
    Obtient l'URL d'un projet dans Azure DevOps pour l'organisation spécifiée.
.PARAMETER Org
    Nom de l'organisation dans Azure DevOps.
.PARAMETER Project
    Nom du projet dans Azure DevOps.
.EXAMPLE
    # Obtient l'URL pour le projet Manhattan de l'organisation DoD.
    Get-ProjectUrl -Org DoD -Project Manhattan
.INPUTS
    System.String
.OUTPUTS
    System.Uri
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Org,

        [Parameter(Mandatory=$true)]
        [string]
        $Project
    )

    [System.Uri]"$(Get-OrgUrl -Org $Org)/$Project"
}

function Get-HttpAuthorizationHeader {
<#
.SYNOPSIS
    Obtient l'entête HTTP d'autorisation à partir d'un jeton personnel d'accès d'Azure DevOps.
.DESCRIPTION
    Obtient l'entête HTTP d'autorisation Authorize correspondant à un jeton personnel d'accès
    (personal access token) d'Azure DevOps. Dépend de la présence du jeton comme valeur
    de la variable d'environnement AZURE_DEVOPS_EXT_PAT.
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>

    if ($null -eq $env:AZURE_DEVOPS_EXT_PAT) {
        throw "Le jeton personnel d'accès à Azure DevOps doit être renseigné comme variable d'environnement AZURE_DEVOPS_EXT_PAT."
    }

    $cred = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(":$($env:AZURE_DEVOPS_EXT_PAT)"))

    @{
        'Authorization' = "Basic $cred"
    }
}

function Get-HttpHeaders {
<#
.SYNOPSIS
    Obtient les entêtes HTTP pour faire une requête à l'API REST d'Azure DevOps.
.DESCRIPTION
    Obtient les entêtes HTTP requis pour faire une requête à l'API REST d'Azure DevOps,
    en particulier les entêtes Authorization, Accept et Content-Type. Dépend de la présence
    d'un jeton personnel d'accès à Azure DevOps (PAT) comme valeur de la variable d'environnement
    AZURE_DEVOPS_EXT_PAT.
.PARAMETER IsPost
    Commutateur qui indique si la requête est une requête POST, dans quel cas la version
    d'API sera spécifiée dans l'entête Accept.
.EXAMPLE
    # Obtient les entêtes HTTP
    Get-HttpHeaders
.EXAMPLE
    # Obtient les entêtes HTTP pour une requête POST
    Get-HttpHeaders -IsPost
.INPUTS
    System.Management.Automation.SwitchParameter
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding()]
    param (
        [Parameter()]
        [Switch]
        $IsPost
    )

    (Get-HttpAuthorizationHeader) + @{
        'Content-Type'  = 'application/json'
        'Accept'        = "application/json$($IsPost ? '; api-version=6.0' : $null)"
    }
}

Export-ModuleMember -Function Get-OrgUrl, Get-ProjectUrl, Get-HttpHeaders