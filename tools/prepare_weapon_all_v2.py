"""New reference-led production inventory. Never consumes rejected v6/v8 designs."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
# Reference prefix, primary motifs, atmospheric material, physical fragment.
DESIGNS={
600:('ea17a0','short crimson curved cut','dense falling crimson wedge','open crimson fan with trailing tear filaments','muted crimson grey air','ruby-dark flake'),
601:('b53481','cold silver needle and black feather','concentrated long silver thrust','three convergent silver raven beak punctures','cold grey air','black feather barb'),
602:('504940','ivory gold folded silk hook','thick descending silk hook','open returning ivory gold silk crescent','warm ivory mist','torn silk flap'),
603:('bd5d7f','paired offset crimson thorn hooks','inward convergent thorn wedges','crossing broad dark red thorn hooks','red grey haze','ruby thorn'),
604:('db6ee3','thin silver lunar sliver','falling narrow silver lunar edge','three staggered silver moon crescents','cold grey moon dust','silver sliver'),
605:('cea1c3','short warm ivory wax edge with black trailing smoke','compressed black wax wedge with amber rim','three sweeping burnt wax folds with glowing candle edges','charcoal warm grey smoke','small black wax chip'),
609:('db6ee3','one pale lavender glass arc with offset reflection','two converging mirror plates','three offset mirrored silver lavender crescent facets','cool lavender grey haze','one clear glass triangular shard'),
610:('504940','slender bronze slash with a curved sound rib','dense bronze blade edge and three close vibration ribs','open fan of bronze sound ribs and narrow ivory resonance edges','warm pale grey incense','one bronze bell chip'),
611:('ea889b','short dark obsidian wedge with silver violet rim','solid angular obsidian falling plate','three overlapping angular dark obsidian cutting planes, bright narrow rims','dark slate violet dust','one glossy black obsidian flake'),
613:('a6489f','short translucent teal water hook','heavy folded teal water crest with white foam lip','open layered turquoise wave crest and white edge spray','soft sea grey spray','one clear water droplet'),
615:('c416c1','short low molten orange slag shear','one heavy charcoal hammer contact with thin molten seams','forward fan of dark furnace slag plates and amber thin seams','dense soft brown grey dust','one charred slag fragment'),
616:('ac0595','compact ivory ice axe hook','dense bone-white icy axe wedge','three forward ivory ice ridges with cold blue transparent planes','low cold grey frost mist','one pale ivory ice splinter'),
618:('bd5d7f','low dark blood red execution edge','steep tall crimson guillotine blade face','broad falling dark red execution crescent with few thin crimson tears','dark muted red mist','one dark red flake'),
619:('2097f3','short grey starstone hammer wake with tiny gold flecks','one dark stone slab shock with fine pale gold seams','layered open fan of dark starstone plates with tiny gold star flecks','soft mineral grey dust','one grey stone chip with tiny gold fleck'),
620:('c416c1','charcoal low shearing edge with ember rim','one thick charcoal wall plate with glowing cracks','forward broken fan of charred wall plates with fine amber edges','low charcoal brown dust','one black charcoal flake'),
621:('a6489f','thin pale green long halberd wind cut','one stretched folded wind banner sheet','open three-lobed pale jade wind banner sweep with thin white cutting edge','airy pale green grey wisps','one torn green cloth thread'),
622:('c34b81','short deep purple inward soul hook','one heavy smoky violet hooked blade face','three open interwoven violet soul cloth hooks with few blue ghost motes','soft grey purple soul mist','one violet translucent soul cloth scrap'),
623:('2097f3','short old silver gold steel cut','one broad aged steel falling edge','three staggered worn silver gold crown blade planes with tiny metal chips','low warm grey mineral dust','one old gold steel plate chip'),
624:('b53481','small cold silver rifle muzzle needle flash','one concentrated narrow silver muzzle flash','three silver muzzle spokes and small cold gas puff','pale grey ballistic smoke','one brass metal chip'),
625:('c67a3c','small teal white feathered bow release','one taut long teal feather release','open three-feather teal bow release fan','soft sea green grey air','one teal feather barb'),
626:('ea17a0','small crimson thorn crossbow release','concentrated dark crimson thorn release','three tiny thorn tipped crimson release spokes','muted red grey air','one crimson thorn chip'),
627:('cea1c3','short amber black cinder muzzle flash','one dense ember-cored muzzle tongue','three forked ember muzzle tongues with short black smoke curl','soft charcoal grey gun smoke','one burnt ember flake'),
628:('ac0595','short pale blue ice bowstring flash','one crystalline ice needle release','three fine ice vane release spokes','soft cold grey frost air','one icy feather vane'),
629:('e03632','very compact lilac silver electric muzzle spike','one concentrated white violet electric muzzle needle','three short branching white violet release spokes','faint lavender grey ion air','one silver metal sliver'),
630:('e201d3','short black purple armour piercing muzzle wedge','one dense black obsidian muzzle wedge with narrow violet edge','three dark angular muzzle splinters with silver purple rim','soft dark slate grey smoke','one black obsidian fleck'),
631:('db6ee3','TWO short silver lavender mirror muzzle spikes','two converging mirrored silver muzzle wedges','three offset pairs of reflective muzzle spokes','cool pale grey smoke','one small reflective glass chip'),
632:('7835d2','short pale olive white feather bow flash','one fine bright wind needle release','three swept wind feather release spokes','faint olive grey air','one small pale feather barb'),
633:('2808c8','small bronze gold muzzle spike with tiny broken red seal','one concentrated bronze sabot release','three narrow bronze release spokes with small red wax chips','warm grey powder smoke','one brass sabot chip'),
634:('504940','small bronze ivory spirit crossbow release','one narrow bronze resonant release with sound rib','three bronze ivory release spokes and fine sound ribs','pale warm grey incense','one bronze vane chip'),
635:('cea1c3','small orange white signal flare muzzle tongue','one dense amber signal flare release','three warm gold muzzle tongues with small star flecks','soft warm grey flare smoke','one tiny gold spark chip'),
636:('d91937','small lavender star focus pulse','one compact silver purple star lance release','long lavender silver stream with three small aligned star contacts','faint lavender grey star dust','one tiny crystalline star chip'),
637:('c416c1','small molten rock seed release','one dense ember rock focus release','one descending dark meteor shell and compact amber contact fan','soft charcoal brown smoke','one black meteor rock fragment'),
638:('ac0595','small white blue frost needle release','one tight clustered ice needle focus','five finely spaced white blue frost needle spokes','soft cold grey mist','one tiny blue ice splinter'),
639:('ff66f7','small sharp white violet lightning focus','one compact branching violet focus','one forked white violet lightning contact crown with dark central gap','faint lavender grey ion mist','one tiny violet white spark shard'),
640:('db6ee3','small silver lunar focus slash','one compact falling silver crescent release','three aligned silver lunar cutting planes on a long thin axis','soft cold grey moon dust','one silver blue lunar flake'),
641:('c56de9','small sharp gold ivory prism alignment','one tight convergent gold prism pulse','long thin gold white beam with three diamond shaped prism facets','faint warm grey gold dust','one tiny clear gold prism chip'),
642:('cea1c3','small glowing amber feather release','one focused dark ember feather release','five open amber fire feather spokes with dark feather cores','soft warm grey ash mist','one burnt black feather vane'),
643:('ed145e','small dark violet inward spiral focus','one compact compressed dark void core','asymmetric dark violet inward folded vortex with thin purple rim and large dark gaps','soft dark violet grey vapour','one dark violet space flake'),
644:('e201d3','small black crimson eclipse lance release','one focused dark shell lance release','long black violet narrow eclipse spear beam with fine magenta red edge','soft dark slate purple vapour','one black purple shell chip'),
645:('bd5d7f','small crimson ink page fold release','one condensed red ink contract page focus','open fan of crimson ink parchment folds and tiny wax fragments','soft muted red grey ink mist','one torn crimson parchment scrap'),
646:('c34b81','small blue violet soul cloth release','one compact folded violet soul focus','three violet soul cloth sheets with small blue ghost motes converging inward','soft pale grey violet mist','one blue violet cloth scrap'),
647:('504940','small warm gold ivory prayer fold release','one compact bronze white prayer focus','three flowing warm ivory gold prayer cloth folds and fine resonance ribs','soft warm pale grey incense','one tiny bronze prayer bell chip')
}

def choreography(records):
    from weapon_varied_arts import write
    write()


def prepare():
    base=ROOT/'art/weapon-all-v2'; base.mkdir(exist_ok=True,parents=True)
    (base/'.gdignore').touch()
    catalog=json.loads((ROOT/'resources/rogue_build_content.json').read_text(encoding='utf-8'))['weapons']
    refs=list((ROOT/'output/texiaocankao').glob('*.png'))
    path=base/'production.json'
    previous=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'weapons':[]}
    existing={r['id']:r for r in previous['weapons']}
    records=[]
    for at,(weapon,(prefix,normal,heavy,finisher,mist,shard)) in enumerate(DESIGNS.items()):
        source=next(p for p in refs if p.stem.startswith('exec-'+prefix))
        item=catalog[weapon-600]
        record={'id':weapon,'name':item['name'],'family':item['family'],'batch':2+at//5,
                'reference':str(source),'normal':normal,'heavy':heavy,'finisher':finisher,
                'mist':mist,'shard':shard,'art_kind':item['art']['kind'],'spell':item['spell'],
                'original_art':item['art'],'status':'queued'}
        record.update({k:v for k,v in existing.get(weapon,{}).items() if k in ['status','storyboard','atlas','original','sha256','qa']})
        records.append(record)
    result={'scope':'All remaining 42 weapons; work in groups of five without waiting between groups, authorized by user 2026-10-20',
            'size':'Per-weapon authored ranges; staff heavy .65 of previous range/radius; staff arts length 320-430, radius 45-82',
            'runtime_revision':'varied-arts-ground-3','review':'output/weapon-revision-v3/index.html',
            'actors':'Keep existing original sprites and atlases', 'weapons':records}
    choreography(records)
    specs=json.loads((ROOT/'resources/weapon_choreography_v2.json').read_text(encoding='utf-8'))
    for item in records: item['current_choreography']=specs[str(item['id'])]
    path.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{len(records)} remaining weapons, {(len(records)+4)//5} production groups')

if __name__=='__main__': prepare()
