std = 'lua51'

quiet = 1 -- suppress report output for files without warnings

-- see https://luacheck.readthedocs.io/en/stable/warnings.html#list-of-warnings
exclude_files = {
    '.github/**',
}

ignore = {
    '212', -- unused argument (callback signatures)
    '611', -- line contains only whitespace
    '612', -- line contains trailing whitespace
    '614', -- trailing whitespace in comment
    '631', -- line is too long
}

read_globals = {
    table = {fields = {'wipe'}},

    -- namespaces
    'C_Spell',
    'C_SpellBook',
    'Enum',

    -- constants
    'WOW_PROJECT_BURNING_CRUSADE_CLASSIC',
    'WOW_PROJECT_CAMELOT',
    'WOW_PROJECT_CATACLYSM_CLASSIC',
    'WOW_PROJECT_CLASSIC',
    'WOW_PROJECT_ID',
    'WOW_PROJECT_MAINLINE',
    'WOW_PROJECT_MISTS_CLASSIC',
    'WOW_PROJECT_WRATH_CLASSIC',

    -- API
    'CreateFrame',
    'LibStub',
    'UnitClass',
}
