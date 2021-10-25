[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
param()
BeforeAll {
    Try {
        $moduleName = 'PSZabbix'
        $moduleRoot = "$PSScriptRoot/../../"
        Import-Module $moduleRoot/$moduleName.psd1 -Force

        $global:baseUrl = $env:DEV_ZABBIX_API_URL
        if ('' -eq $global:baseUrl) {
            $global:baseUrl = "http://tools/zabbix/api_jsonrpc.php"
        }
        $secpasswd = ConvertTo-SecureString "zabbix" -AsPlainText -Force
        $global:admin = New-Object System.Management.Automation.PSCredential ("Admin", $secpasswd)

        $wrongsecpasswd = ConvertTo-SecureString "wrong" -AsPlainText -Force
        $global:admin2 = New-Object System.Management.Automation.PSCredential ("Admin", $wrongsecpasswd)

        $PesterSession = New-ZbxApiSession $baseUrl $global:admin -silent

        $testTemplate = Get-ZbxTemplate | Select-Object -First 1
        $testTemplateId = $testTemplate.templateid
    } Catch {
        $e = $_
        Write-Warning "Error setup Tests $e $($_.exception)"
        Throw $e
    }

}
AfterAll {
    Remove-Module $moduleName
}

Describe "New-ZbxApiSession" {
    BeforeAll {
        $session = New-ZbxApiSession $baseUrl $admin -silent
    }

    It "connects to zabbix and returns a non-empty session object" {
        $session | Should -Not -BeNullOrEmpty
        $session["Uri"] | Should -Not -BeNullOrEmpty
        $session["Auth"] | Should -Not -BeNullOrEmpty
        $session["ApiVersion"] | Should -Not -BeNullOrEmpty
        $session["ApiVersion"] | Should -BeOfType [Version]
    }

    It "fails when URL is wrong" {
        { New-ZbxApiSession "http://localhost:12345/zabbix" $admin } | Should -Throw
    }

    It "fails when login/password is wrong" {
        { New-ZbxApiSession $baseUrl $admin2 } | Should -Throw
    }
}

Describe "New-ZbxHost" {
    AfterAll {
        Get-ZbxHost 'pestertesthost*' | Remove-ZbxHost
    }
    It "can create an enabled host from explicit ID parameters" {
        $h = New-ZbxHost -Name "pestertesthost$(Get-Random)" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost
        $h | Should -Not -Be $null
        $h.status | Should -Be 0
    }
    It "can create an disabled host from explicit ID parameters" {
        $h = New-ZbxHost -Name "pestertesthost$(Get-Random)" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost -status disabled
        $h | Should -Not -Be $null
        $h.status | Should -Be 1
    }
    It "should throw if invalid Group or template Id" {
        { New-ZbxHost -Name "pestertesthost$(Get-Random)" -HostGroupId 2 -TemplateId 9999 -Dns localhost -status disabled } | Should -Throw
        { New-ZbxHost -Name "pestertesthost$(Get-Random)" -HostGroupId 9999 -TemplateId $testTemplateId -Dns localhost -status disabled } | Should -Throw
    }
}

Describe "Get-ZbxHost" {
    BeforeAll {
        $h1 = New-ZbxHost -Name "pestertesthost1" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost
        $h2 = New-ZbxHost -Name "pestertesthost2" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost
    }
    It "can return all hosts" {
        Get-ZbxHost | Should -Not -BeNullOrEmpty
    }
    It "can filter by name with wildcard (explicit parameter)" {
        Get-ZbxHost "pestertesthost*" | Should -Not -BeNullOrEmpty
        Get-ZbxHost "pestertesthostXXX*" | Should -BeNullOrEmpty
    }
    It "can filter by ID (explicit parameter)" {
        $h = (Get-ZbxHost "pestertesthost*")[0]
        (Get-ZbxHost -Id $h.hostid).host | Should -Be $h.host
    }
    It "can filter by group membership (explicit parameter)" {
        $h = (Get-ZbxHost "pestertesthost*")[0]
        (Get-ZbxHost -Id $h.hostid -HostGroupId 2).host | Should -Be $h.host
    }
}

Describe "Remove-ZbxHost" {
    BeforeEach {
        $h1 = New-ZbxHost -Name "pestertesthostrem" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost -errorAction silentlycontinue
        $h2 = New-ZbxHost -Name "pestertesthostrem2" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost -errorAction silentlycontinue
        # if the test before failed e.g. because the host already exists, New-Host returns $null
        if ($null -eq $h1) { $h1 = Get-ZbxHost "pestertesthostrem" }
        if ($null -eq $h2) { $h2 = Get-ZbxHost "pestertesthostrem2" }
    }
    AfterAll {
        remove-ZbxHost $h1.hostid, $h2.hostid -ErrorAction silentlycontinue
    }
    It "can delete from one explicit ID parameter" {
        remove-ZbxHost $h1.hostid | Should -Be $h1.hostid
    }
    It "can delete from multiple explicit ID parameters" {
        remove-ZbxHost $h1.hostid, $h2.hostid | Should -Be @($h1.hostid, $h2.hostid)
    }
    It "can delete from multiple piped IDs" {
        $h1.hostid, $h2.hostid | remove-ZbxHost | Should -Be @($h1.hostid, $h2.hostid)
    }
    It "can delete from one piped object parameter" {
        $h1 | remove-ZbxHost | Should -Be $h1.hostid
    }
    It "can delete from multiple piped objects" {
        $h1, $h2 | remove-ZbxHost | Should -Be @($h1.hostid, $h2.hostid)
    }
}

Describe "Disable-ZbxHost" {
    BeforeAll {
        New-ZbxHost -Name "pestertesthost1" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost -errorAction silentlycontinue
        New-ZbxHost -Name "pestertesthost2" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost -errorAction silentlycontinue
        $h1 = Get-ZbxHost pestertesthost1
        $h2 = Get-ZbxHost pestertesthost2
    }
    AfterAll {
        Remove-ZbxHost $h1.HostId,$h2.HostId
    }

    It "can enable multiple piped objects" {
        $h1, $h2 | Disable-ZbxHost | Should -Be @($h1.hostid, $h2.hostid)
        (Get-ZbxHost pestertesthost1).status | Should -Be 1
    }
    It "can enable multiple piped IDs" {
        $h1.hostid, $h2.hostid | Disable-ZbxHost | Should -Be @($h1.hostid, $h2.hostid)
        (Get-ZbxHost pestertesthost1).status | Should -Be 1
    }
    It "can enable multiple explicit parameter IDs" {
        Disable-ZbxHost $h1.hostid, $h2.hostid | Should -Be @($h1.hostid, $h2.hostid)
        (Get-ZbxHost pestertesthost1).status | Should -Be 1
    }
}

Describe "Enable-ZbxHost" {
    BeforeAll {
        New-ZbxHost -Name "pestertesthost1" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost -errorAction silentlycontinue
        New-ZbxHost -Name "pestertesthost2" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost -errorAction silentlycontinue
        $h1 = Get-ZbxHost pestertesthost1
        $h2 = Get-ZbxHost pestertesthost2
    }
    BeforeEach {
        Disable-ZbxHost $h1.hostid, $h2.hostid
    }
    AfterAll {
        Remove-ZbxHost $h1.HostId,$h2.HostId
    }

    It "can enable multiple piped objects" {
        $h1, $h2 | Enable-ZbxHost | Should -Be @($h1.hostid, $h2.hostid)
        (Get-ZbxHost pestertesthost1).status | Should -Be 0
    }
    It "can enable multiple piped IDs" {
        $h1.hostid, $h2.hostid | Enable-ZbxHost | Should -Be @($h1.hostid, $h2.hostid)
        (Get-ZbxHost pestertesthost1).status | Should -Be 0
    }
    It "can enable multiple explicit parameter IDs" {
        Enable-ZbxHost $h1.hostid, $h2.hostid | Should -Be @($h1.hostid, $h2.hostid)
        (Get-ZbxHost pestertesthost1).status | Should -Be 0
    }
}

Describe "Add-ZbxHostGroupMembership" {
    BeforeAll {
        New-ZbxHost -Name "pestertesthost1" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost -errorAction silentlycontinue
        New-ZbxHost -Name "pestertesthost2" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost -errorAction silentlycontinue
        $h1 = Get-ZbxHost pestertesthost1
        $h2 = Get-ZbxHost pestertesthost2
        New-ZbxHostGroup "pestertest1" -errorAction silentlycontinue
        New-ZbxHostGroup "pestertest2" -errorAction silentlycontinue
        $g1 = Get-ZbxHostGroup pestertest1
        $g2 = Get-ZbxHostGroup pestertest2
    }
    AfterAll {
        Remove-ZbxHostGroup $g1.GroupId
        Remove-ZbxHostGroup $g2.GroupId
        Get-ZbxHost 'pestertesthost*' | Remove-ZbxHost
    }

    It "adds a set of groups given as a parameter to multiple piped hosts" {
        $h1, $h2 | Add-ZbxHostGroupMembership $g1, $g2
        (Get-ZbxHostGroup pestertest1).hosts.Count | Should -Be 2
    }
}

Describe "Remove-ZbxHostGroupMembership" {
    BeforeAll {
        New-ZbxHost -Name "pestertesthost1" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost -errorAction silentlycontinue
        New-ZbxHost -Name "pestertesthost2" -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost -errorAction silentlycontinue
        $h1 = Get-ZbxHost pestertesthost1
        $h2 = Get-ZbxHost pestertesthost2
        New-ZbxHostGroup "pestertest1" -errorAction silentlycontinue
        New-ZbxHostGroup "pestertest2" -errorAction silentlycontinue
        $g1 = Get-ZbxHostGroup pestertest1
        $g2 = Get-ZbxHostGroup pestertest2
    }
    AfterAll {
        Remove-ZbxHostGroup $g1.GroupId -ErrorAction silentlycontinue
        Remove-ZbxHostGroup $g2.GroupId -ErrorAction silentlycontinue
        Get-ZbxHost 'pestertesthost*' | Remove-ZbxHost -ErrorAction silentlycontinue
    }

    It "removes a set of groups given as a parameter to multiple piped hosts" {
        $h1, $h2 | Remove-ZbxHostGroupMembership $g1, $g2
        (Get-ZbxHostGroup pestertest1).hosts.Count | Should -Be 0
    }
}

Describe "Get-ZbxTemplate" {
    It "can return all templates" {
        Get-ZbxTemplate | Should -Not -BeNullOrEmpty
    }
    It "can filter by name with wildcard (explicit parameter)" {
        Get-ZbxTemplate "Template OS Lin*" | Should -Not -BeNullOrEmpty
        Get-ZbxTemplate "XXXXXXXXXXXXXX" | Should -BeNullOrEmpty
    }
    It "can filter by ID (explicit parameter)" {
        $h = (Get-ZbxTemplate "Template OS Lin*")[0]
        (Get-ZbxTemplate -Id $h.templateid).host | Should -Be $h.host
    }
}

Describe "New-ZbxHostGroup" {
    It "creates a new group with explicit name parameter" {
        $g = New-ZbxHostGroup "pestertest$(Get-Random)", "pestertest$(Get-Random)"
        $g.count | Should -Be 2
        $g[0].name | Should -Match "pestertest"
    }
    It "creates a new group with piped names" {
        $g = "pestertest$(Get-Random)", "pestertest$(Get-Random)" | New-ZbxHostGroup
        $g.count | Should -Be 2
        $g[0].name | Should -Match "pestertest"
    }
    It "creates a new group with piped objects" {
        $g = (New-Object -TypeName PSCustomObject -Property @{name = "pestertest$(Get-Random)" }), (New-Object -TypeName PSCustomObject -Property @{name = "pestertest$(Get-Random)" }) | New-ZbxHostGroup
        $g.count | Should -Be 2
        $g[0].name | Should -Match "pestertest"
    }
}

Describe "Get-ZbxHostGroup" {
    It "can return all groups" {
        $ret = Get-ZbxHostGroup
        $ret | Should -Not -BeNullOrEmpty
        $ret.Count | Should -BeGreaterThan 1
    }
    It "can filter by name with wildcard (explicit parameter)" {
        $ret = Get-ZbxHostGroup "pestertest*"
        $ret | Should -Not -BeNullOrEmpty
        $ret.name | Should -BeLike 'pestertest*'
        $ret = Get-ZbxHostGroup "XXXXXXXXXXXXXX"
        $ret | Should -BeNullOrEmpty
    }
    It "can filter by ID (explicit parameter)" {
        $h = (Get-ZbxHostGroup "pestertest*")[0]
        (Get-ZbxHostGroup -Id $h.groupid).name | Should -Be $h.name
    }
}

Describe "Remove-ZbxHostGroup" {
    It "can delete from one explicit ID parameter" {
        New-ZbxHostGroup -Name "pestertestrem" -errorAction silentlycontinue
        $h = Get-ZbxHostGroup pestertestrem
        remove-ZbxHostGroup $h.groupid | Should -Be $h.groupid
        Get-ZbxHostGroup pestertestrem | Should -BeNullOrEmpty
    }
    It "can delete from multiple explicit ID parameters" {
        $h1 = New-ZbxHostGroup -Name "pestertestrem"
        $h2 = New-ZbxHostGroup -Name "pestertestrem2" -errorAction silentlycontinue
        $h2 = Get-ZbxHostgroup pestertestrem2
        remove-ZbxHostgroup $h1.groupid, $h2.groupid | Should -Be @($h1.groupid, $h2.groupid)
        Get-ZbxHostGroup pestertestrem | Should -BeNullOrEmpty
        Get-ZbxHostGroup pestertestrem2 | Should -BeNullOrEmpty
    }
    It "can delete from multiple piped IDs" {
        $h1 = New-ZbxHostGroup -Name "pestertestrem"
        $h2 = New-ZbxHostGroup -Name "pestertestrem2"
        $h1.groupid, $h2.groupid | remove-ZbxHostgroup | Should -Be @($h1.groupid, $h2.groupid)
    }
    It "can delete from one piped object parameter" {
        $h = New-ZbxHostGroup -Name "pestertestrem"
        $h | remove-ZbxHostgroup | Should -Be $h.groupid
    }
    It "can delete from multiple piped objects" {
        $h1 = New-ZbxHostGroup -Name "pestertestrem"
        $h2 = New-ZbxHostGroup -Name "pestertestrem2"
        $h1, $h2 | remove-ZbxHostgroup | Should -Be @($h1.groupid, $h2.groupid)
    }
}

Describe "Get-ZbxUserGroup" {
    It "can return all groups" {
        Get-ZbxUserGroup | Should -Not -BeNullOrEmpty
    }
    It "can filter by name with wildcard (explicit parameter)" {
        Get-ZbxUserGroup "Zabbix*" | Should -Not -BeNullOrEmpty
        Get-ZbxUserGroup "XXXXXXXXXXXXXX" | Should -BeNullOrEmpty
    }
    It "can filter by ID (explicit parameter)" {
        $h = (Get-ZbxUserGroup "Zabbix*")[0]
        (Get-ZbxUserGroup -Id $h.usrgrpid).name | Should -Be $h.name
    }
}

Describe "New-ZbxUserGroup" {
    It "creates a new group with explicit name parameter" {
        $g = New-ZbxUserGroup "pestertest$(Get-Random)", "pestertest$(Get-Random)"
        $g.count | Should -Be 2
        $g[0].name | Should -Match "pestertest"
    }
    It "creates a new group with piped names" {
        $g = "pestertest$(Get-Random)", "pestertest$(Get-Random)" | New-ZbxUserGroup
        $g.count | Should -Be 2
        $g[0].name | Should -Match "pestertest"
    }
    It "creates a new group with piped objects" {
        $g = (New-Object -TypeName PSCustomObject -Property @{name = "pestertest$(Get-Random)" }), (New-Object -TypeName PSCustomObject -Property @{name = "pestertest$(Get-Random)" }) | New-ZbxUserGroup
        $g.count | Should -Be 2
        $g[0].name | Should -Match "pestertest"
    }
}

Describe "Remove-ZbxUserGroup" {
    It "can delete from one explicit ID parameter" {
        New-ZbxUserGroup -Name "pestertestrem" -errorAction silentlycontinue
        $h = Get-ZbxUserGroup pestertestrem
        Remove-ZbxUserGroup $h.usrgrpid | Should -Be $h.usrgrpid
        Get-ZbxUserGroup pestertestrem | Should -BeNullOrEmpty
    }
    It "can delete from multiple explicit ID parameters" {
        $h1 = New-ZbxUserGroup -Name "pestertestrem"
        $h2 = New-ZbxUserGroup -Name "pestertestrem2" -errorAction silentlycontinue
        $h2 = Get-ZbxUserGroup pestertestrem2
        remove-ZbxUserGroup $h1.usrgrpid, $h2.usrgrpid | Should -Be @($h1.usrgrpid, $h2.usrgrpid)
        Get-ZbxUserGroup pestertestrem | Should -BeNullOrEmpty
        Get-ZbxUserGroup pestertestrem2 | Should -BeNullOrEmpty
    }
    It "can delete from multiple piped IDs" {
        $h1 = New-ZbxUserGroup -Name "pestertestrem"
        $h2 = New-ZbxUserGroup -Name "pestertestrem2"
        $h1.usrgrpid, $h2.usrgrpid | remove-ZbxUserGroup | Should -Be @($h1.usrgrpid, $h2.usrgrpid)
    }
    It "can delete from one piped object parameter" {
        $h = New-ZbxUserGroup -Name "pestertestrem"
        $h | remove-ZbxUserGroup | Should -Be $h.usrgrpid
    }
    It "can delete from multiple piped objects" {
        $h1 = New-ZbxUserGroup -Name "pestertestrem"
        $h2 = New-ZbxUserGroup -Name "pestertestrem2"
        $h1, $h2 | remove-ZbxUserGroup | Should -Be @($h1.usrgrpid, $h2.usrgrpid)
    }
}

Describe "Get-ZbxUser" {
    It "can return all users" {
        $ret = Get-ZbxUser
        $ret | Should -Not -BeNullOrEmpty
    }
    It "can filter by name with wildcard (explicit parameter)" {
        $ret = Get-ZbxUser "Admi*"
        $ret | Should -Not -BeNullOrEmpty
        $ret | Should -HaveCount 1
        if ($PesterSession.ApiVersion.Major -eq 3) {
            $ret.Alias | Should -Be 'Admin'
        }
        $ret.Name | Should -Be 'Zabbix'
    }
    It "can filter by ID (explicit parameter)" {
        $h = Get-ZbxUser "Admin"
        $h | Should -HaveCount 1
        (Get-ZbxUser -Id $h.userid).alias | Should -Be $h.alias
    }
    It "returns nothing on unknown user" {
        $ret = Get-ZbxUser "XXXXXXXXXXXXXX"
        $ret | Should -BeNullOrEmpty
        $ret = Get-ZbxUser -Id 9999999
        $ret | Should -BeNullOrEmpty
    }
}

Describe "New-ZbxUser" {
    BeforeAll {
        $userToCopy = "pestertest$(Get-random)"
    }
    AfterAll {
        Get-ZbxUser 'pestertest*' | Remove-ZbxUser
    }
    It "creates a new user with explicit parameters" {
        $g = @(New-ZbxUser -Alias $userToCopy -name "marsu" -UserGroupId 8)
        $g.count | Should -Be 1
        $g[0].name | Should -Match "marsu"
    }
    #TODO: fix example
    It "creates a new user from another user (copy)" -Skip {
        $u = Get-ZbxUser -Name $userToCopy
        #        $u = @(New-ZbxUser -Alias "pestertest$(Get-random)" -name "marsu" -UserGroupId 8)
        $g = $u | New-ZbxUser -alias "pestertest$(Get-random)"
        $g.userid | Should -Not -Be $null
        $g.name | Should -Match "marsu"
        $g.usrgrps.usrgrpid | Should -Be 8
    }
    It "throws on incompatible role&type params" {
        {New-ZbxUser  -Alias $userToCopy -name "marsu" -UserGroupId 8 -UserType 'User' -RoleId 2} |
            Should -Throw "Parameter combination not allowed*"
    }
}

Describe "Remove-ZbxUser" {
    BeforeEach {
        New-ZbxUser -Alias "pestertestrem" -UserGroupId 8 -errorAction silentlycontinue | Should -Not -BeNullOrEmpty
        New-ZbxUser -Alias "pestertestrem2" -UserGroupId 8 -errorAction silentlycontinue  | Should -Not -BeNullOrEmpty
        $user1 = Get-ZbxUser -Name 'pestertestrem'
        $user2 = Get-ZbxUser -Name 'pestertestrem2'
    }
    AfterEach {
        Remove-ZbxUser $user1.userid -ErrorAction silentlycontinue
        Remove-ZbxUser $user2.userid -ErrorAction silentlycontinue
    }
    It "can delete from one explicit ID parameter" {
        Remove-ZbxUser $user1.userid | Should -Be $user1.userid
        Get-ZbxUser pestertestrem | Should -BeNullOrEmpty
    }
    It "can delete from multiple explicit ID parameters" {
        Remove-ZbxUser $user1.userid, $user2.userid | Should -Be @($User1.userid, $User2.userid)
        Get-ZbxUser pestertestrem  | Should -BeNullOrEmpty
        Get-ZbxUser pestertestrem2 | Should -BeNullOrEmpty
    }
    It "can delete from multiple piped IDs" {
        $user1.userid, $user2.userid | Remove-ZbxUser | Should -Be @($user1.userid, $user2.userid)
    }
    It "can delete from one piped object parameter" {
        $user1 | Remove-ZbxUser | Should -Be $user1.userid
    }
    It "can delete from multiple piped objects" {
        $user1, $user2 | Remove-ZbxUser | Should -Be @($user1.userid, $user2.userid)
    }
}

Describe "Get-ZbxUserRole" {
    Context "ContextName" {
        It "should read all roles" {
            $ret = Get-ZbxUserRole
            $ret.Count | Should -BeGreaterThan 0
            $ret.Name | Should -Contain 'Admin role'
        }
        It "can read by roleid" {
            $ret = Get-ZbxUserRole -Id 1
            $ret.Count | Should -BeExactly 1
            $ret.Name | Should -Contain 'User role'
        }
        It "can read by role name" {
            $ret = Get-ZbxUserRole -Name "Guest role"
            $ret.Count | Should -BeExactly 1
            $ret.Name | Should -Contain 'Guest role'
        }
        It "can read by wildcard role name" {
            $ret = Get-ZbxUserRole -Name "Guest*"
            $ret.Count | Should -BeExactly 1
            $ret.Name | Should -Contain 'Guest role'
        }
    }
}

Describe "Add-ZbxUserGroupMembership" {
    It "can add two user groups (explicit parameter) to piped users" {
        Get-ZbxUser "pester*" | Remove-ZbxUser
        Get-ZbxUserGroup "pester*" | remove-ZbxUserGroup

        $g1 = New-ZbxUserGroup -Name "pestertestmembers"
        $g2 = New-ZbxUserGroup -Name "pestertestmembers2"
        $g1 = Get-ZbxUserGroup pestertestmembers
        $g2 = Get-ZbxUserGroup pestertestmembers2

        $u1 = New-ZbxUser -Alias "pestertestrem" -UserGroupId 8
        $u2 = New-ZbxUser -Alias "pestertestrem2" -UserGroupId 8
        $u1 = Get-ZbxUser pestertestrem
        $u2 = Get-ZbxUser pestertestrem2

        $u1, $u2 | Add-ZbxUserGroupMembership $g1, $g2 | Should -Be @($u1.userid, $u2.userid)
        $u1 = Get-ZbxUser pestertestrem
        $u2 = Get-ZbxUser pestertestrem2
        $u1.usrgrps | Select-Object -ExpandProperty usrgrpid | Should -Be @(8, $g1.usrgrpid, $g2.usrgrpid)
    }
    It "same with ID instead of objects" {
        Get-ZbxUser "pester*" | Remove-ZbxUser
        Get-ZbxUserGroup "pester*" | remove-ZbxUserGroup

        $g1 = New-ZbxUserGroup -Name "pestertestmembers3"
        $g2 = New-ZbxUserGroup -Name "pestertestmembers4"
        $g1 = Get-ZbxUserGroup pestertestmembers3
        $g2 = Get-ZbxUserGroup pestertestmembers4

        $u1 = New-ZbxUser -Alias "pestertestrem3" -UserGroupId 8
        $u2 = New-ZbxUser -Alias "pestertestrem4" -UserGroupId 8
        $u1 = Get-ZbxUser pestertestrem3
        $u2 = Get-ZbxUser pestertestrem4

        $u1.userid, $u2.userid | Add-ZbxUserGroupMembership $g1.usrgrpid, $g2.usrgrpid | Should -Be @($u1.userid, $u2.userid)
        $u1 = Get-ZbxUser pestertestrem3
        $u2 = Get-ZbxUser pestertestrem4
        $u1.usrgrps | Select-Object -ExpandProperty usrgrpid | Should -Be @(8, $g1.usrgrpid, $g2.usrgrpid)
    }
}

Describe "Remove-ZbxUserGroupMembership" {
    It "can remove two user groups (explicit parameter) to piped users" {
        Get-ZbxUser "pester*" | Remove-ZbxUser
        Get-ZbxUserGroup "pester*" | remove-ZbxUserGroup

        $g1 = New-ZbxUserGroup -Name "pestertestmembers"
        $g2 = New-ZbxUserGroup -Name "pestertestmembers2"
        $g1 = Get-ZbxUserGroup pestertestmembers
        $g2 = Get-ZbxUserGroup pestertestmembers2

        $u1 = New-ZbxUser -Alias "pestertestrem" -UserGroupId 8
        $u2 = New-ZbxUser -Alias "pestertestrem2" -UserGroupId 8
        $u1 = Get-ZbxUser pestertestrem
        $u2 = Get-ZbxUser pestertestrem2

        $u1, $u2 | Add-ZbxUserGroupMembership $g1, $g2 | Should -Be @($u1.userid, $u2.userid)
        $u1, $u2 | Remove-ZbxUserGroupMembership $g1, $g2 | Should -Be @($u1.userid, $u2.userid)
        $u1 = Get-ZbxUser pestertestrem
        $u2 = Get-ZbxUser pestertestrem2
        $u1.usrgrps | Select-Object -ExpandProperty usrgrpid | Should -Be @(8)
    }
    It "same with ID instead of objects" {
        Get-ZbxUser "pester*" | Remove-ZbxUser
        Get-ZbxUserGroup "pester*" | remove-ZbxUserGroup

        $g1 = New-ZbxUserGroup -Name "pestertestmembers3"
        $g2 = New-ZbxUserGroup -Name "pestertestmembers4"
        $g1 = Get-ZbxUserGroup pestertestmembers3
        $g2 = Get-ZbxUserGroup pestertestmembers4

        $u1 = New-ZbxUser -Alias "pestertestrem3" -UserGroupId 8
        $u2 = New-ZbxUser -Alias "pestertestrem4" -UserGroupId 8
        $u1 = Get-ZbxUser pestertestrem3
        $u2 = Get-ZbxUser pestertestrem4

        $u1.userid, $u2.userid | Add-ZbxUserGroupMembership $g1.usrgrpid, $g2.usrgrpid | Should -Be @($u1.userid, $u2.userid)
        $u1 = Get-ZbxUser pestertestrem3
        $u2 = Get-ZbxUser pestertestrem4
        $u1.usrgrps | Select-Object -ExpandProperty usrgrpid | Should -Be @(8, $g1.usrgrpid, $g2.usrgrpid)
        $u1.userid, $u2.userid | Remove-ZbxUserGroupMembership $g1.usrgrpid, $g2.usrgrpid | Should -Be @($u1.userid, $u2.userid)
        $u1 = Get-ZbxUser pestertestrem3
        $u2 = Get-ZbxUser pestertestrem4
        $u1.usrgrps | Select-Object -ExpandProperty usrgrpid | Should -Be @(8)
    }
}

Describe "Add-ZbxUserGroupPermission" {
    BeforeAll {
        Get-ZbxHostGroup "pester*" | remove-ZbxHostGroup -ErrorAction silentlycontinue
        Get-ZbxUserGroup "pester*" | remove-ZbxUserGroup -ErrorAction silentlycontinue
    }
    AfterAll {
        Get-ZbxHostGroup "pester*" | remove-ZbxHostGroup
        Get-ZbxUserGroup "pester*" | remove-ZbxUserGroup
    }
    It "can add a Read permission to two piped user groups on two host groups" {

        New-ZbxUserGroup -Name "pestertest1", "pestertest2"
        $ug1 = Get-ZbxUserGroup pestertest1
        $ug2 = Get-ZbxUserGroup pestertest2

        New-ZbxHostGroup "pestertest1", "pestertest2"
        $hg1 = Get-ZbxHostGroup pestertest1
        $hg2 = Get-ZbxHostGroup pestertest2

        $ug1, $ug2 | Add-ZbxUserGroupPermission $hg1, $hg2 ReadWrite | Should -Be @($ug1.usrgrpid, $ug2.usrgrpid)
        $ug1 = Get-ZbxUserGroup pestertest1
        $ug2 = Get-ZbxUserGroup pestertest2
        $ug1.rights | Select-Object -ExpandProperty id | Should -Be @($hg1.groupid, $hg2.groupid)
        $ug1.rights | Select-Object -ExpandProperty permission | Should -Be @(3, 3)
    }
    It "can alter and clear permissions on a host group without touching permissions on other groups" {
        $ug1 = Get-ZbxUserGroup pestertest1
        $ug2 = Get-ZbxUserGroup pestertest2
        $hg1 = Get-ZbxHostGroup pestertest1
        $hg2 = Get-ZbxHostGroup pestertest2

        # Sanity check
        $ug1.rights | Select-Object -ExpandProperty id | Should -Be @($hg1.groupid, $hg2.groupid)
        $ug1.rights | Select-Object -ExpandProperty permission | Should -Be @(3, 3)

        # Set HG1 RO.
        $ug1, $ug2 | Add-ZbxUserGroupPermission $hg1 ReadOnly | Should -Be @($ug1.usrgrpid, $ug2.usrgrpid)
        $ug1 = Get-ZbxUserGroup pestertest1
        $ug2 = Get-ZbxUserGroup pestertest2
        $ug1.rights | Select-Object -ExpandProperty id | Should -Be @($hg1.groupid, $hg2.groupid)
        $ug1.rights | Select-Object -ExpandProperty permission | Should -Be @(2, 3)

        # Clear HG1
        $ug1, $ug2 | Add-ZbxUserGroupPermission $hg1 Clear | Should -Be @($ug1.usrgrpid, $ug2.usrgrpid)
        $ug1 = Get-ZbxUserGroup pestertest1
        $ug2 = Get-ZbxUserGroup pestertest2
        $ug1.rights | Select-Object -ExpandProperty id | Should -Be @($hg2.groupid)
        $ug1.rights | Select-Object -ExpandProperty permission | Should -Be @(3)
    }
}


Describe "Disable-ZbxUserGroup, Enable-ZbxUserGroup" {
    BeforeAll {
        New-ZbxUserGroup -Name "pestertestenable1" -errorAction silentlycontinue
        New-ZbxUserGroup -Name "pestertestenable2" -errorAction silentlycontinue
        $h1 = Get-ZbxUserGroup pestertestenable1
        $h2 = Get-ZbxUserGroup pestertestenable2
    }
    AfterAll {
        Get-ZbxUserGroup 'pestertestenable1' | Remove-ZbxUserGroup
        Get-ZbxUserGroup 'pestertestenable2' | Remove-ZbxUserGroup
    }

    It "can disable a singe objects" {
        # default after creation is "enabled"
        $h1.users_status | Should -Be 0

        Disable-ZbxUserGroup $h1.usrgrpid | Should -Be @($h1.usrgrpid)
        [int](Get-ZbxUserGroup pestertestenable1).users_status | Should -Be 1
        [int](Get-ZbxUserGroup pestertestenable2).users_status | Should -Be 0 -Because 'should be left enabled'

        $h1 | Enable-ZbxUserGroup | Should -Be @($h1.usrgrpid)
        [int](Get-ZbxUserGroup pestertestenable1).users_status | Should -Be 0
    }
    It "can disable and enable multiple piped objects" {
        # default after creation is "enabled"
        $h1.users_status | Should -Be 0

        $h1, $h2 | Disable-ZbxUserGroup | Should -Be @($h1.usrgrpid, $h2.usrgrpid )
        [int[]](Get-ZbxUserGroup pestertestenable*).users_status | Should -Be @(1,1)

        $h1 | Enable-ZbxUserGroup | Should -Be @($h1.usrgrpid)
        [int](Get-ZbxUserGroup pestertestenable1).users_status | Should -Be 0
    }
}

Describe "Update-ZbxHost" {
    BeforeAll {
        $name = "pestetesthost$(Get-Random)"
        Get-ZbxHost -name "pester*" | remove-ZbxHost
        Get-ZbxHost -name "newname" | remove-ZbxHost
        $h = New-ZbxHost -Name $name -HostGroupId 2 -TemplateId $testTemplateId -Dns localhost -errorAction silentlycontinue
    }

    It "can update the name of a host" {
        $h.name = "newname"
        $h | Update-ZbxHost
        Get-ZbxHost -id $h.hostid | Select-Object -ExpandProperty name | Should -Be "newname"
        Remove-ZbxHost $h.hostId
    }
}

#region media tests
AfterAll {
    Get-ZbxUser 'pestertestmedia*' | Remove-ZbxUser -ErrorAction silentlycontinue
}

Describe "Get-ZbxMediaType" {
    It "can return all types" {
        Get-ZbxMediaType | Should -Not -BeNullOrEmpty
    }
    It "can filter by technical media type" {
        Get-ZbxMediaType -type Email | Should -Not -BeNullOrEmpty
        Get-ZbxMediaType -type Webhook | Should -Not -BeNullOrEmpty
    }
}

Describe "Add-ZbxUserMail" {
    BeforeAll {
        $mailUser = @(New-ZbxUser -Alias "pestertestmediaemail" -name "marsu" -UserGroupId 8)[0]
    }
    AfterAll {
        $mailUser | Remove-ZbxUser
    }
    It "can add email media to user" {
        $mediaids = $mailUser | Add-ZbxUserMail toto1@company.com
        $mediaids | Should -BeOfType [int]
    }
    #TODO
    It "can add second email media to a user" -Skip {

    }
    #TODO: if it does make sense to do that?
    It "cann add email to multiple users" -skip {

    }
}

Describe "Get-ZbxMedia" {
    Context "with no users defined" {
        It "returns nothing" {
            $ret = Get-ZbxMedia
            $ret |  Should -BeNullOrEmpty
        }
    }
    Context "with users having media defined" {
        BeforeAll {
            $u1 = @(New-ZbxUser -Alias "pestertestmedia$(Get-random)" -name "marsu" -UserGroupId 8)[0]
            $u1 | Add-ZbxUserMail toto1@company.com | Should -Not -BeNullOrEmpty
            $u2 = @(New-ZbxUser -Alias "pestertestmedia$(Get-random)" -name "marsu" -UserGroupId 8)[0]
            $u2 | Add-ZbxUserMail toto1@company.com Information, Warning | Should -Not -BeNullOrEmpty
        }
        AfterAll {
            Remove-ZbxUser $u1.UserId
            Remove-ZbxUser $u2.UserId
        }
        It "can return all media" {
            $ret = Get-ZbxMedia
            $ret | Should -HaveCount 2
        }
        It "can filter by media type" {
            $ret = Get-ZbxMedia -MediaTypeId (Get-ZbxMediaType -Type email).mediatypeid
            $ret | Should -HaveCount 2
        }
        It "can filter actions used by certain users" {
            $ret = Get-ZbxMedia -UserId @(Get-ZbxUser -Name "pestertestmedia*")[0].userid
            $ret | Should -HaveCount 1
        }
        #TODO: check for a user having 2 different media types
    }
}

Describe "Remove-ZbxMedia" {
    It "can remove piped media" -Skip {
        Get-ZbxMedia | Remove-ZbxMedia |  Should -Not -BeNullOrEmpty
        Get-ZbxMedia |  Should -BeNullOrEmpty
        Get-ZbxUser -Name "pestertestmedia*" | Remove-ZbxUser > $null
    }
}

#endregion
