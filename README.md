# LibDispel

Worlf of Warcraft library to help track dispelable auras

## Usage

```lua
local LibDispel = LibStub("LibDispel")
assert(LibDispel, "Addon requires LibDispel")

-- data obtained from event "UNIT_AURA"
local unit = "player"
local spellID = 703 -- Garrote
local dispelName = nil

local dispelType = LibDispel:GetDispelType(spellID, dispelName)
local isDispelable = LibDispel:IsDispelable(unit, spellID, dispelType, true)
assert(dispelType == "Bleed" and not isDispelable)
```
