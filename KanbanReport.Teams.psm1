# Kanban Report - opérations sur les Teams

Import-Module -Name $PSScriptRoot\KanbanReport.Api.psm1

filter Find-ItemWasCreatedBy ([PSCustomObject]$People) {
<#
.SYNOPSIS
    Trouve les éléments de travail qui ont été créés par les membres de l'équipe spécifiée.
    Ce filtre agit sur des objets qui exposent une propriété CreatedByName.
.DESCRIPTION
    Trouve les éléments de travail qui ont été créés par les membres de l'équipe spécifiée par
    le paramètre People formé d'une liste d'objets avec les propriétés Name et Email. Ce filtre
    agit sur des objets qui exposent une propriété CreatedByName.
.PARAMETER People
    Objet contenant les personnes membres de l'équipe, et qui a été généré par ConvertTo-Person.
#>
    ($People.Name -contains $_.CreatedByName) ? $_ : $null
}

function Get-TeamMembers {
<#
.SYNOPSIS
    Obtient les membres d'une équipe dans Azure DevOps.
.DESCRIPTION
    Obtient les membres d'une équipe dans Azure DevOps et retourne une liste d'objets avec le nom et l'adresse courriel
    de chaque membre.
.PARAMETER Org
    Nom de l'organisation dans Azure DevOps.
.PARAMETER Project
    Nom du projet dans Azure DevOps.
.PARAMETER Team
    Nom de l'équipe dont on désire obtenir les membres.
.EXAMPLE
    # Obtient les membres de l'équipe Lab du projet Manhattan de l'organisation DoD.
    Get-TeamMembers -Org DoD -Project Manhattan -Team Lab
.INPUTS
    System.String
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Org,

        [Parameter(Mandatory=$true)]
        [string]
        $Project,

        [Parameter(Mandatory=$true)]
        [string]
        $Team
    )

    $urlTeam = "$(Get-OrgUrl -Org $Org)/_apis/projects/$Project/teams/$Team/members"
    $equipe = ((Invoke-WebRequest $urlTeam -Headers (Get-HttpHeaders)).Content | ConvertFrom-Json).value.identity |
        ConvertTo-Person
    
    $equipe
}

function ConvertTo-Person {
<#
.SYNOPSIS
    Convertit en objet avec un nom et une adresse courriel un objet représentant un utilisateur Azure DevOps.
.DESCRIPTION
    Convertit en objet avec un nom et une adresse courriel un objet représentant un utilisateur Azure DevOps.
    Les informations de l'utilisateur Azure DevOps doivent provenir d'une requête à l'API REST d'Azure DevOps
    pour respecter le format attendu.
.PARAMETER DevOpsUser
    Object qui contient les informations d'un utilisateur d'Azure DevOps. On s'attend aux propriétés
    displayName pour le nom et uniqueName pour l'adresse courriel.
.EXAMPLE
    ('{ "AssignedTo": { "displayName": "Frère Untel", "uniqueName": "frereUntel@anonyme.org" } }' | ConvertFrom-Json).AssignedTo | ConvertTo-Person
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject[]]
        $DevOpsUser
    )

    BEGIN {}

    PROCESS {
        foreach ($u in $DevOpsUser) {
            if ($u.isContainer -eq $true) { $null } else {
                [PSCustomObject]@{
                    Name  = $u.displayName
                    Email = $u.uniqueName
                }
            }
        }
    }

    END {}
}

Export-ModuleMember -Function Get-TeamMembers, ConvertTo-Person, Find-ItemWasCreatedBy