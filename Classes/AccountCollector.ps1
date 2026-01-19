#Requires -Version 7.0

<#
.SYNOPSIS
    Collector for ESXi local accounts and permissions.
#>

class AccountCollector : ESXiCollectorBase {
    AccountCollector() : base('Account') {}

    [ESXiEntity[]] Collect([object]$vmHost) {
        $entities = [System.Collections.ArrayList]::new()
        
        # Local user accounts
        try {
            # Note: Get-VMHostAccount doesn't accept -VMHost when connected directly to ESXi
            # It operates on the currently connected host
            $accounts = Get-VMHostAccount -ErrorAction Stop
            
            foreach ($account in $accounts) {
                $props = @{
                    Id = $account.Id
                    Name = $account.Name
                    Description = $this.GetProperty($account, 'Description', '')
                    # Note: Not capturing passwords for security
                }

                $entity = [ESXiEntity]::new('Account', $account.Id, "Account/$($account.Id)", $props)
                $entities.Add($entity) | Out-Null
            }
        } catch {
            Write-Verbose "Failed to get accounts: $_"
        }

        # Permissions
        try {
            $permissions = Get-VIPermission -Entity $vmHost -ErrorAction SilentlyContinue
            
            foreach ($perm in $permissions) {
                $props = @{
                    Principal = $perm.Principal
                    Role = $perm.Role
                    Entity = $perm.Entity.Name
                    IsGroup = $perm.IsGroup
                    Propagate = $perm.Propagate
                }

                $entity = [ESXiEntity]::new('Account', "Perm-$($perm.Principal)", "Account/Permission/$($perm.Principal)", $props)
                $entities.Add($entity) | Out-Null
            }
        } catch {
            Write-Verbose "Failed to get permissions: $_"
        }

        return $entities.ToArray()
    }
}
