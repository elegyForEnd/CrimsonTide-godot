"""Keep the underground source and the small sword seal unambiguous in Chinese."""
REPLACEMENTS = (
    ('同源母晶器', '同源晶石器'),
    ('同源母晶', '同源赤晶'),
    ('剑柄里的母晶', '剑柄里的契印晶核'),
    ('剑柄的母晶', '剑柄的契印晶核'),
    ('剑柄母晶', '契印晶核'),
    ('同体母晶', '同体晶核'),
    ('母晶编号', '赤月晶材编号'),
    ('母晶', '赤月之心'),
)


def normalize(value):
    if isinstance(value, str):
        for old, new in REPLACEMENTS:
            value = value.replace(old, new)
        return value
    if isinstance(value, list):
        return [normalize(item) for item in value]
    if isinstance(value, tuple):
        return tuple(normalize(item) for item in value)
    if isinstance(value, dict):
        return {key: normalize(item) for key, item in value.items()}
    return value
