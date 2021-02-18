# Kanban Report Time Functions

filter Find-ItemWasCreatedOrModifiedOnPreviousWorkday ([DateTime]$ReferenceDate = (Get-Date)) {
<#
.SYNOPSIS
    Trouve les éléments de travail qui ont été créés ou modifiés le jour ouvrable précédent
    la date de référence. Ce fitre agit sur des objets qui exposent les propriétés
    CreatedDate (requis) et ModifiedDate (optionnel).
.DESCRIPTION
    Trouve les éléments de travail qui ont été créés ou modifiés le jour ouvrable précédent
    la date de référence. Ce fitre agit sur des objets qui exposent les propriétés
    CreatedDate (requis) et ModifiedDate (optionnel).
.PARAMETER ReferenceDate
    Date de référence pour déterminer le jour ouvrable précédent.
#>
    $day = Get-PreviousWorkDay -ReferenceDate $ReferenceDate
    ($_.CreatedDate.Date -eq $day -or $_.ModifiedDate.Date -eq $day) ? $_ : $null
}

function Get-PreviousWorkDay {
<#
.Synopsis
    Obtient le jour ouvrable précédent la date spécifiée, ou la date courante.
.Description
    Obtient le jour ouvrable précédent la date spécifiée, ou la date courante.
    Si aucune date n'est spécifiée, retourne le jour ouvrable précédent la date courante.
.Parameter ReferenceDate
    Date de référence à partir de laquelle on doit déterminer le jour ouvrable précédent.
    Si non spécifiée, la date courante sera utilisée.
.Example
    # Obtient le jour ouvrable précédent
    Get-PreviousWorkDay
.Example
    # Obtient le jour ouvrable précédent une date de référence
    Get-PreviousWorkDay -ReferenceDate Get-Date -Date '2021-02-14'
.Inputs
    System.DateTime
.Outputs
    System.DateTime
#>

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true)]
        [DateTime]
        $ReferenceDate = (Get-Date)
    )

    $nbreDernierJourOuvre = if ($ReferenceDate.DayOfWeek -eq [System.DayOfWeek]::Monday) { -3 } else { -1 }

    $ReferenceDate.Date.AddDays($nbreDernierJourOuvre)
}

Export-ModuleMember -Function Find-ItemWasCreatedOrModifiedOnPreviousWorkday, Get-PreviousWorkDay