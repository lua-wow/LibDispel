# LibDispel

Worlf of Warcraft library to help track dispelable auras

## Usage

```lua
local LibDispel = LibStub("LibDispel")
assert(LibDispel, "Addon requires LibDispel")

local frame = CreateFrame("Frame")
frame:RegisterEvent("UNIT_AURA")
frame:SetScript("OnEvent", function (self, event, ...)
    if event == "UNIT_AURA" then
        local unit, updateInfo = ...

        local isFullUpdate = not updateInfo or updateInfo.isFullUpdate
        if isFullUpdate then
            self.all = table.wipe(self.all or {})
            self.actives = table.wipe(self.actives or {})
            changed = true

            local slots = { C_UnitAuras.GetAuraSlots(unit, self.filter) }
            for i = 2, #slots do -- #1 return is continuationToken, we don't care about it
                local aura = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])

                -- dispelType will be equal to aura.dispelName, if the aura is "Magic", "Poison", "Curse" or "Disease"
                -- but dispelType can return "Bleed" or "Enrage" too
                local dispelType = LibDispel:GetDispelType(aura.spellId, aura.dispelName)

                -- check if you can dispel this aura
                local isDispelable = LibDispel:IsDispelable(unit, aura.spellId, dispelType, true)
            end
        end
    end
end)
```
