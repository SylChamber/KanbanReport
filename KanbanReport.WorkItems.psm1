# Kanban Report - opérations sur les work items

Import-Module -Name $PSScriptRoot\KanbanReport.Api.psm1
Import-Module -Name $PSScriptRoot\KanbanReport.Teams.psm1

function Get-CurrentUserStories {
<#
.SYNOPSIS
    Obtient d'Azure DevOps les récits utilisateurs en cours ou fermés le jour ouvré précédent.
.DESCRIPTION
    Obtient d'Azure DevOps les récits utilisateurs en cours ou fermés le jour ouvré précédent
    pour l'organisation et le projet spécifiés.
.PARAMETER Org
    Nom de l'organisation Azure DevOps pour laquelle on doit récupérer les récits utilisateurs.
.PARAMETER Project
    Nom du projet pour lequel on doit récupérer les récits utilisateurs.
.EXAMPLE
    # Obtient les récits utilisateurs du projet Manhattan du DoD.
    Get-CurrentUserStories -Org DoD -Project Manhattan
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
        $Project
    )

    $urlApis = "$(Get-ProjectUrl -Org $Org -Project $Project)/_apis"
    $urlWiql = "$urlApis/wit/wiql"
    $urlWorkItems = "$urlApis/wit/workitems?ids="

    # préparer requête pour les cartes en cours ou les cartes fermées la veille
    $wiql = "Select Id from WorkItems where [Work Item Type] = 'User Story' and [Area Path] under 'CEI' and (State in ('Active', 'Validation', 'Attente') or (State = 'Closed' and [Closed Date] >= @Today - 1)) order by [Changed Date] DESC"
    $body = [PSCustomObject]@{
        query = $wiql
    } | ConvertTo-Json

    # obtenir les nos de cartes
    $reponseNos = (Invoke-WebRequest $urlWiql -Headers (Get-HttpHeaders -IsPost) -Method Post -Body $body).Content |
        ConvertFrom-Json
    $nosCartesEnCours = $reponseNos.workItems.id -join ','

    # obtenir le détail des cartes
    $reponseCartes = (Invoke-WebRequest "$urlWorkItems$nosCartesEnCours" -Headers (Get-HttpHeaders)).Content |
        ConvertFrom-Json
    # rendre la structure d'objet plus conviviale
    $cartes = $reponseCartes | ConvertTo-UserStory

    # obtenir les commentaires de chaque carte
    $cartes | ForEach-Object {
        $_.Comments = (Invoke-WebRequest "$($_.Url)/comments" -Headers (Get-HttpHeaders)).Content |
            ConvertFrom-Json | ConvertTo-Comment
        if ($null -ne $_.Comments) {
            $_.Comments | ForEach-Object {
                $carte = $cartes | Where-Object Id -eq $_.WorkItemId
                $_.WorkItemTitle = $carte.Title
                $_.WorkItemState = $carte.State
                $_.WorkItemBoard = $carte.Board
            }
        }
    }

    $cartes
}

function ConvertTo-UserStory {
<#
.SYNOPSIS
    Convertit en objet représentant un User Story une réponse de requête WIQL à l'API REST Azure DevOps.
.DESCRIPTION
    Convertit en objet représentant un User Story une réponse de requête WIQL à l'API REST Azure DevOps.
    Le paramètre WiqlQueryResponse doit inclure une propriété 'value' qui inclut les informations du Work Item
    dans Azure DevOps (les propriétés id et url et le array fields).
.PARAMETER WiqlQueryResponse
    Objet qui contient la réponse (Content) en JSON d'une requête faite à Azure DevOps avec le
    point de terminaison WIQL.
.INPUTS
    System.Management.Automation.PSCustomObject
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject[]]
        $WiqlQueryResponse
    )

    BEGIN {}

    PROCESS {
        foreach ($reponse in $WiqlQueryResponse) {
            $reponse.value | ForEach-Object {
                [PSCustomObject]@{
                    Id                 = $_.id
                    WorkItemType       = $_.fields.'System.WorkItemType'
                    Title              = $_.fields.'System.Title'
                    AreaPath           = $_.fields.'System.AreaPath'
                    Board              = $_.fields | ConvertTo-Board
                    State              = $_.fields.'System.State'
                    AssignedTo         = if ($null -eq $_.fields.'System.AssignedTo') { $null } else {
                        $_.fields.'System.AssignedTo' | ConvertTo-Person
                    }
                    AssignedToName     = $_.fields.'System.AssignedTo'.displayName ?? $null
                    Description        = $_.fields.'System.Description'
                    AcceptanceCriteria = $_.fields.'Microsoft.VSTS.Common.AcceptanceCriteria'
                    ChangedDate        = $_.fields.'System.ChangedDate'.ToLocalTime()
                    ClosedDate         = $_.fields.'Microsoft.VSTS.Common.ClosedDate' ? 
                        $_.fields.'Microsoft.VSTS.Common.ClosedDate'.ToLocalTime() : 
                        $null
                    ClosedBy           = if ($null -eq $_.fields.'Microsoft.VSTS.Common.ClosedBy') { $null } else {
                        $_.fields.'Microsoft.VSTS.Common.ClosedBy' | ConvertTo-Person
                    }
                    ClosedByName       = $_.fields.'Microsoft.VSTS.Common.ClosedBy'.displayName ?? $null
                    Tags               = $_.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() }
                    Comments           = @()
                    Url                = $_.url
                }
            }
        }
    }

    END {}
}

function ConvertTo-Comment {
<#
.SYNOPSIS
    Convertit en objet représentant un commentaire d'un élément de travail
    un objet provenant d'une réponse de l'API REST d'Azure DevOps.
.DESCRIPTION
    Convertit en objet représentant un commentaire d'un élément de travail
    un objet provenant d'une réponse de l'API REST d'Azure DevOps.
.INPUTS
    System.Management.Automation.PSCustomObject
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject[]]
        $CommentEndpointResponse
    )

    BEGIN {}

    PROCESS {
        foreach ($response in $CommentEndpointResponse) {
            $response.comments | ForEach-Object {
                [PSCustomObject]@{
                    Id            = $_.id
                    WorkItemId    = $_.workItemId
                    WorkItemTitle = $null
                    WorkItemState = $null
                    WorkItemBoard = $null
                    Version       = $_.version
                    Text          = $_.text
                    CreatedBy     = $_.createdBy | ConvertTo-Person
                    CreatedByName = $_.createdBy.displayName
                    CreatedDate   = $_.createdDate.ToLocalTime()
                    ModifiedBy    = if ($null -eq $_.modifiedBy) { $null } else { $_.modifiedBy | ConvertTo-Person }
                    ModifiedDate  = $_.modifiedDate ? $_.modifiedDate.ToLocalTime() : $null
                    Url           = $_.url
                }
            }        
        }
    }

    END {}
}

function ConvertTo-Board {
<#
.SYNOPSIS
    Convertit en objet représentant un tableau Kanban un objet provenant
    d'une réponse de l'API REST d'Azure DevOps.
.DESCRIPTION
    Convertit en objet représentant un tableau Kanban un objet provenant
    d'une réponse de l'API REST d'Azure DevOps.
.EXAMPLE
    # convertit une réponse en objet représentant un tableau Kanban.
@'
{
    "System.BoardColumnDone": false,
    "System.BoardColumn": "Réalisation"
}
'@ | ConvertFrom-Json | ConvertTo-Board
.INPUTS
    System.Management.Automation.PSCustomObject
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject[]]
        $FieldsSet
    )

    BEGIN {}

    PROCESS {
        foreach ($fields in $FieldsSet) {
            [PSCustomObject]@{
                Column     = $fields."System.BoardColumn"
                ColumnDone = $fields."System.BoardColumnDone" ?? $null
                Lane       = $fields."System.BoardLane" ?? $null
                Rank       = $_.fields.'Microsoft.VSTS.Common.StackRank' ?? $null
            }
        
        }
    }

    END {}
}

Export-ModuleMember -Function Get-CurrentUserStories