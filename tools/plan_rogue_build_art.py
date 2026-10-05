"""Describe atlas assets and stable cells; generation itself uses the built-in image tool."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
data=json.loads((ROOT/'resources/rogue_build_content.json').read_text(encoding='utf-8'))
weapons=[
 ['crimson straight longsword','raven beak thin thrusting rapier','silver curved returning scimitar','paired thorn daggers','silver moon dueling rapier','candle shadow dagger','frost crystal arming sword','lightning officer sabre','broken oath dark straight sword','mirror flower curved sabre','funeral silver bell ritual sword','black obsidian law sword'],
 ['gold dawn two handed sword','broad tidal cleaver greatsword','cracked earth massive sword','forge volcanic war hammer','frost bone war axe','thunder bone greatsword','blood prison execution blade','meteor stone maul','ember bulwark shield blade','storm long halberd','spectral tide ritual scythe','nameless black royal greatsword'],
 ['nightwatch silver raven rifle','twilight feather longbow','thorn blood repeating crossbow','ember raven flintlock','frost moon hunting bow','lightning wing carbine','obsidian long sniper rifle','paired mirror pistols','wind feather shortbow','broken oath armor piercing musket','funeral bell spirit crossbow','dawn signal pistol'],
 ['star crystal wand','red meteor scepter','slender frost needle wand','forked lightning staff','crescent moon arc staff','dawn prismatic crystal staff','fan of burning feather staff','violet vortex staff','dark eclipse spear staff','blood covenant ritual wand','spectral royal summoning staff','morning bell prayer staff']]
talent_motifs=[
 ['sharpening bloody sword on whetstone','blood filament sewing needle','watchful red eye with three drops','pulsing crimson heart with moon','protective blood clot shield','reaping crimson crescent blade','blood and fire entwined hands','blood pact radiant covenant heart'],
 ['forge hammer striking heavy blade','cracked war hammer shock','planted greatsword at feet','wedged armor piercing iron spike','glowing rift under sword','returning hammer beside blue mana spiral','lightning cracking ground','towering shattered war banner'],
 ['silver raven bullet feather','far sight telescope','hand loading rifle magazine','hunting stamp target','precision execution scope','piercing bullet crossing shield','silver ammunition reserve belt','raven carrying radiant marked target'],
 ['single orange fire seed','candle burning into night','ember furnace heart','heat resistant gauntlet','branching wildfire candle','warm healing embers in palm','frozen crystal bursting in flame','crown of volcanic embers'],
 ['frost rune inscribed on glass','hourglass frozen in winter','mirror shard ice strike','calm meditating blue lotus','protective ice shell','winter crystal fracture','ice mirror radiant afterglow','frozen covenant moon crest'],
 ['lightning rune engraving','lightning around winged boot','seeking branching electric arc','steady eye of storm','electric vein with mana bead','crossed lightning chains','electric returning arrow','radiant lightning wing circuit'],
 ['large overflowing star pool orb','breathing crystal water spring','high tide refracted prism','simplified geometric magic scroll','casting wand afterglow','star silk mana shield','spring eye concentric blue echoes','radiant star spring resonance orb'],
 ['open tome of weapon techniques','empty sound tuning fork rhythm','mana blue measuring dial','low tide spiral eye','blade handing baton to wand','echoing torn music parchment','cut musical note returning mana','rotating silvery resonant ring'],
 ['fortified iron bone','black iron protective shield','warm embers behind shield','ruined city final tower','counterattacking blade behind shield','thorn gauntlet reflecting strike','healing dying embers','radiant ember oath citadel crest'],
 ['nightwatch light boot','double wind step footprints','instant flipped knife','breathing wind feather','silent invisible moon mask','chasing wind returning blade','reverse shadow footprints','radiant wind movement clock'],
 ['small violet soul flame','spectral royal messenger bell','spirit lamp hourglass','bone bell echoes','spirit lord two resonant souls','violet necromantic command hand','protective curtain of ghosts','radiant spectral covenant crown'],
 ['morning bell robust heart','two clasped hands praying','clear voice water ripple bell','rescue hands raising fallen ally','prayer chain holy seals','protective paired sacred sigils','morning light radiant blade','radiant morning bell alliance crest']]
plans=[]
def add(key,entries,category,motifs=None):
    cols=4; rows=len(entries)//4
    palette={'weapons':'crimson, cold silver, ember gold, frost blue, violet magic accents','gear':'black iron, worn gold, crimson, cold blue and violet accents','talents':'individual school colors: blood red, ember orange, frost cyan, lightning blue, spectral violet, dawn gold','engravings':'silver and aged gold engraved metal with colored magical channels','cores':'crimson light blade, gold heavy blade, blue ranged, violet spellcasting'}[category]
    prompt=f'''Use case: stylized-concept.
Asset type: a production transparent icon atlas for the dark fantasy action game Crimson Tide.
Primary request: Paint {len(entries)} DISTINCT high quality game inventory icons as one coherent atlas asset, arranged in exactly {cols} equal columns and {rows} equal rows. Each icon is centered within its own equal-size cell, ordered left-to-right then top-to-bottom. Every cell has generous 16 percent transparent padding; no icon, effect or glow crosses its own cell. {'Square canvas.' if rows==3 else 'Portrait canvas with aspect ratio 2:3, so the individual cells are square.'}
Style: polished hand-painted dark fantasy 2D item illustration, strong recognizable silhouette and crisp highlights readable at 48px; match ornate crimson crescent and silver/aged-gold aesthetic. Palette: {palette}. 
Subjects in precise cell order:
'''
    for i,e in enumerate(entries):
        motif=motifs[i] if motifs else e['name']+'; '+str(e.get('text',e.get('desc','')))
        prompt+=f"Cell {i+1} (row {i//4+1}, column {i%4+1}): {e['name']} — {motif}.\n"
    if category=='weapons': prompt+='Each cell contains the entire weapon, diagonally oriented from lower left hilt to upper right point or barrel, ready to be used as a transparent game sprite. Deliberately distinct shapes and material accents for every weapon.\n'
    elif category=='gear': prompt+='Each cell contains only one piece of tangible equipment. Armor cells are complete chest armor or robe without a wearer; focus cells are amulets, seals, prisms or mechanical sights; boot cells show one boot or a neatly paired set of boots.\n'
    elif category=='talents': prompt+='Each cell is a unique emblem with the explicitly described central symbol. Use a small ornamental crescent base where useful, with core emblems more ornate and luminous than normal talents. No repeated generic orbs replacing the subjects.\n'
    elif category=='engravings': prompt+='Each cell is a unique physical metal rune medallion with an abstract engraved symbol communicating the ability. The rune may use imaginary geometric ornament, never a readable letter.\n'
    else: prompt+='Each cell is a unique tangible weapon mastery emblem combining its named weapon family with its special motif.\n'
    prompt+='Genuinely transparent background. No grid lines, no tile backgrounds, no labels, no letters, no numbers, no text, no watermark, no scene, no decorative frame around the atlas. Exactly the requested number of icons; do not omit or duplicate any cell.'
    plans.append(dict(key=key,columns=cols,rows=rows,ids=[e['id'] for e in entries],prompt=prompt,tool='built-in image_gen',file=key+'.png'))
for i in range(4): add('weapons-'+['light','heavy','ranged','staff'][i]+'-v1',data['weapons'][i*12:(i+1)*12],'weapons',weapons[i])
for i in range(3): add('gear-'+['armor','focus','boots'][i]+'-v1',data['gear'][i*24:(i+1)*24],'gear')
for i in range(4): add('talents-'+str(i+1)+'-v1',data['talents'][i*24:(i+1)*24],'talents',sum(talent_motifs[i*3:(i+1)*3],[]))
add('engravings-v1',data['engravings'],'engravings')
add('weapon-cores-v1',data['cores'],'cores')
path=ROOT/'assets/rogue/build/generation-plan.json'
path.write_text(json.dumps(plans,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Planned',len(plans),'atlas assets for',sum(len(p['ids']) for p in plans),'unique build IDs')
