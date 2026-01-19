#Requires -Version 7.0

<#
.SYNOPSIS
    Base class for ESXi configuration collectors.
#>

class ESXiCollectorBase {
    [string]$EntityType
    [bool]$Enabled = $true
    [object]$VMHost

    ESXiCollectorBase([string]$type) {
        $this.EntityType = $type
    }

    # Override in derived classes
    [ESXiEntity[]] Collect([object]$vmHost) {
        throw "Collect() must be implemented in derived class"
    }

    # Helper to safely get property value
    [object] GetProperty([object]$obj, [string]$property, [object]$default = $null) {
        try {
            $val = $obj.$property
            return $null -eq $val ? $default : $val
        }
        catch {
            return $default
        }
    }

    # Helper to get nested property (e.g. "Config.Network.Vswitch")
    [object] GetNestedProperty([object]$obj, [string]$propertyPath, [object]$default = $null) {
        try {
            $current = $obj
            foreach ($prop in $propertyPath -split '\.') {
                $current = $current.$prop
                if ($null -eq $current) { return $default }
            }
            return $current
        }
        catch {
            return $default
        }
    }
}
