function Get-UserRole
{
    param
    (
        [Parameter(Mandatory=$False)]
        # A valid Zabbix API session retrieved with New-ApiSession. If not given, the latest opened session will be used, which should be enough in most cases.
        [Hashtable] $Session,

        [Parameter(Mandatory=$False)][Alias("roleids")]
        # Only retrieve the roles with the given ID
        [int[]] $Id,

        # [Parameter(Mandatory=$False)][Alias("userids")]
        # # Only retrieve the roles with the given ID
        # [int[]] $UserId,

        [Parameter(Mandatory=$False, Position=0)]
        # Filter by name. Accepts wildcard.
        [string] $Name
    )
    if ( (Get-CurrentApiVersion -Session $Session).Major -lt 5 ) {
        Write-Warning "Userrole-Object not defined in this Zabbix version"
    } else {
        $prms = @{searchWildcardsEnabled=$true; search= @{}}
        if ($Id.Length -gt 0) {$prms["roleids"] = $Id}
        # if ($UserId.Length -gt 0) {$prms["userids"] = $UserId}
        if ($Name -ne $null) {$prms["search"]["name"] = $Name}
        Invoke-ZabbixApi $session "role.get"  $prms |
            ForEach-Object {
                $_.roleid = [int]$_.roleid
                $_.type = [ZbxUserType] $_.type
                $_
            }
    }
}
