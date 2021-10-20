function Get-CurrentApiVersion {
    <#
    .SYNOPSIS
    Returns a version object of the current session

    .DESCRIPTION
    Returns a version object of the current session (by parameter or the latest session)

    .PARAMETER Session
    Session object

    .EXAMPLE
    $version = Get-CurrentApiVersion
    Returns a version object of the latests session connected

    .EXAMPLE
    $version = Get-CurrentApiVersion -Session $SomeSession
    Returns a version for the given session (hash)

    .NOTES
    General notes
    #>
    [CmdletBinding()]
    [OutputType('Version')]
    param (
        [hashtable] $Session
    )
    if ($null -eq $Session) {
        $Session = $script:latestSession
    }
    if ($null -eq $Session) {
        throw "No session is opened. Call New-ZabbixApiSession before or pass a previously retrieved session object as a parameter."
    }
    $Session.ApiVersion
}