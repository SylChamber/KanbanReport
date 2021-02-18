# Kanban Report - opérations sur les rapports

Import-Module -Name $PSScriptRoot\KanbanReport.Teams.psm1
Import-Module -Name $PSScriptRoot\KanbanReport.Time.psm1
Import-Module -Name $PSScriptRoot\KanbanReport.WorkItems.psm1
Import-Module -Name Poshstache -Global

function Get-HtmlDailyKanbanReport {
<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.PARAMETER Org
    Nom de l'organisation dans Azure DevOps.
.PARAMETER Project
    Nom du projet dans Azure DevOps.
.PARAMETER Team
    Nom de l'équipe dans Azure DevOps.
.Parameter ReferenceDate
    Date de référence à partir de laquelle on doit déterminer le jour ouvrable précédent pour la génération du rapport.
    Si non spécifiée, la date courante sera utilisée.
.EXAMPLE
    # Génère un rapport d'activité Kanban en HTML et l'écrit dans un fichier HTML.
    Get-HtmlDailyKanbanReport -Org DoD -Project Manhattan -Team Lab | Out-File "KanbanReport.html" -Encoding utf8
.INPUTS
    System.String
.OUTPUTS
    System.String
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
        $Team,

        [Parameter(Mandatory=$false)]
        [DateTime]
        $ReferenceDate = (Get-Date)
    )

    Get-DailyKanbanReport -Org $Org -Project $Project -Team $Team -ReferenceDate $ReferenceDate |
        ConvertTo-HtmlKanbanReport
}

function Get-DailyKanbanReport {
<#
.SYNOPSIS
    Obtient et génère un rapport quotidien d'activité Kanban du jour ouvrable précédent
    pour l'équipe de projet Azure DevOps spécifiée.
.DESCRIPTION
    Obtient et génère un rapport quotidien d'activité Kanban du jour ouvrable précédent
    pour l'équipe de projet Azure DevOps spécifiée.
.PARAMETER Org
    Nom de l'organisation dans Azure DevOps.
.PARAMETER Project
    Nom du projet dans Azure DevOps.
.PARAMETER Team
    Nom de l'équipe dans Azure DevOps.
.Parameter ReferenceDate
    Date de référence à partir de laquelle on doit déterminer le jour ouvrable précédent pour la génération du rapport.
    Si non spécifiée, la date courante sera utilisée.
.EXAMPLE
    # Génère un rapport d'activité Kanban pour l'équipe Lab du projet Manhattan de l'organisation DoD.
    Get-DailyKanbanReport -Org DoD -Project Manhattan -Team Lab
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
        $Team,

        [Parameter(Mandatory=$false)]
        [DateTime]
        $ReferenceDate = (Get-Date)
    )

    $reportDate = Get-PreviousWorkDay -ReferenceDate $ReferenceDate

    $membres = Get-TeamMembers -Org $org -Project $project -Team $team
    $cartes = Get-CurrentUserStories -Org $org -Project $project
    $commentReports = $cartes.Comments |
        Find-ItemWasCreatedOrModifiedOnPreviousWorkday -ReferenceDate $ReferenceDate |
        Find-ItemWasCreatedBy -People $membres |
        Group-Object CreatedByName |
        ConvertTo-CommentReport
    $report = [PSCustomObject]@{
        ReportDate = $reportDate
        Items = $cartes | Select-Object Id,Title,AreaPath,State -ExpandProperty Board
        CommentReports = $commentReports
        Mutes = $membres.Name | Where-Object { $commentReports.Name -notcontains $_ } | Sort-Object
    }

    $report
}

function ConvertTo-CommentReport {
<#
.SYNOPSIS
    Convertit un regroupement de commentaires selon la personne (groupés selon CreatedByName)
    en objet plus convivial (CommentReport).
.DESCRIPTION
    Convertit un regroupement de commentaires selon la personne (groupés selon CreatedByName)
    en objet plus convivial (CommentReport). 
.PARAMETER GroupedComments
    Tableau de commentaires groupés avec Group-Object CreatedByName.
.INPUTS
    System.Management.Automation.PSCustomObject
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject[]]
        $GroupedComments
    )
    
    BEGIN {}
    
    PROCESS {
        foreach ($comment in $GroupedComments) {
            $comment | ForEach-Object {
                [PSCustomObject]@{
                    Name         = $_.Name
                    Count        = $_.Count
                    CommentGroup = $_.Group |
                    Group-Object WorkItemId | 
                    ForEach-Object {
                        [PSCustomObject]@{
                            Count         = $_.Count
                            WorkItemId    = $_.Name
                            WorkItemTitle = $_.Group[0].WorkItemTitle
                            Comments      = $_.Group    
                        }
                    }
                }
            }
        }
    }
    
    END {}
}

function ConvertTo-HtmlKanbanReport {
<#
.SYNOPSIS
    Convertit un rapport d'activité Kanban en HTML.
.DESCRIPTION
    Convertit un rapport d'activité Kanban en HTML.
.PARAMETER Report
    Objet qui représente le rapport d'activité Kanban à convertir en HTML. Doit avoir été généré
    avec Get-DailyKanbanReport.
.EXAMPLE
    #
    Get-DailyKanbanReport -Org DoD -Project Manhattan -Team Lab | ConvertTo-HtmlKanbanReport
.INPUTS
    System.Management.Automation.PSCustomObject
.OUTPUTS
    System.String
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [PSCustomObject]
        $Report
    )

    # Import-Module -Name Poshstache

    $viewModel = ConvertTo-KanbanReportView -Report $report
    $html = ConvertTo-PoshstacheTemplate -InputFile "$PSScriptRoot\KanbanReport.mustache" -ParametersObject ($viewModel | ConvertTo-Json -Depth 10)

    $html
}

function ConvertTo-KanbanReportView {
<#
.SYNOPSIS
    Convertit en modèle de vue un rapport Kanban généré par Get-DailyKanbanReport.
.DESCRIPTION
    Convertit en modèle de vue un rapport Kanban généré par Get-DailyKanbanReport.
    Retourne un Hashtable qui peut être utilisé par un moteur de gabarits (templating engine) pour
    générer un rapport en HTML ou en un autre format.
.PARAMETER Report
    Objet qui représente le rapport d'activité Kanban à convertir en modèle de vue. Doit avoir été généré
    avec Get-DailyKanbanReport.
.EXAMPLE
    # Convertit en modèle de vue un rapport d'activité Kanban pour l'équipe Lab du projet Manhattan de l'organisation DoD.
    ConvertTo-KanbanReportView -Report (Get-DailyKanbanReport -Org DoD -Project Manhattan -Team Lab)
.INPUTS
    System.Management.Automation.PSCustomObject
.OUTPUTS
    System.Collections.Hashtable
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [PSCustomObject]
        $Report
    )

    @{
        ReportDate = $Report.ReportDate.ToString('D', [CultureInfo]'fr-fr')
        CommentReports = ConvertTo-CommentReportView -CommentReports $Report.CommentReports
        Mutes = $Report.Mutes
    }
}

function ConvertTo-CommentReportView {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject[]]
        $CommentReports
    )

    $CommentReports | ForEach-Object {
        $comments = ConvertTo-CommentGroupView -CommentGroups $_.CommentGroup
        $firstCommentInfo = @{
            Name = $_.Name
            TotalCommentCount = $_.Count
        }

        if (($comments | Measure-Object).Count -gt 1) {
            $comments[0] += $firstCommentInfo    
        }
        else {
            $comments += $firstCommentInfo
        }

        $comments
    }
}

function ConvertTo-CommentGroupView {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [PSCustomObject[]]
        $CommentGroups
    )

    $CommentGroups | ForEach-Object {
        $firstComment = @{
            WorkItemCommentCount = $_.Count
            WorkItemId = $_.WorkItemId
            WorkItemTitle = $_.WorkItemTitle
            Text = $_.Comments[0].Text
            CreatedDate = $_.Comments[0].CreatedDate.ToString('g')
            ModifiedDate = $_.Comments[0].ModifiedDate ? $_.Comments[0].ModifiedDate.ToString('g') : $null
        }
        $otherComments = $_.Comments | Select-Object -Skip 1 | ForEach-Object {
            @{
                Text = $_.Text
                CreatedDate = $_.CreatedDate.ToString('g')
                ModifiedDate = $_.ModifiedDate ? $_.ModifiedDate.ToString('g') : $null
            }
        }
        @($firstComment) + $otherComments
    }
}

Export-ModuleMember -Function Get-DailyKanbanReport, Get-HtmlDailyKanbanReport, ConvertTo-HtmlKanbanReport