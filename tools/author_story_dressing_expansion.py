"""Append authored, functional clusters; preserve every existing placement."""
import json,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
path=ROOT/'resources/story-opening-dressing.json'
data=json.loads(path.read_text(encoding='utf-8'))
def put(stage,id,model,at,**options):
    rows=data['regions'].setdefault(str(stage),[])
    if any(row['id']==id for row in rows): return
    rows.append(dict(id=id,model=model,at=at,**options))

# Drains sit beside circulation rather than crossing the cobbled main street.
for i,p in enumerate([(220,670),(1970,780),(280,1180),(2000,1500)]):
    put(0,f'camp_drain_{i}','drain_channel',p)
for i,p in enumerate([(430,1650),(1900,1620)]): put(0,f'camp_supply_wagon_{i}','broken_wagon',p,footprint=[150,140])
put(0,'south_gate_shrine','road_shrine',[840,1720])
put(0,'smith_coal_ridge','strata_outcrop',[220,1040],scale=[.45,.35,.4])

# Place groups according to an abandoned convoy, logging site and eroded ridge.
put(1,'convoy_marker','road_shrine',[1650,1050])
put(1,'convoy_broken_axle','broken_wagon',[1450,850],angle=.45,footprint=[155,180])
put(1,'convoy_spill','cargo',[1250,980],scale=[.7,.7,.7])
put(1,'convoy_rope','rope_coil',[1350,1080])
put(1,'logging_trunk','fallen_oak',[650,3050],angle=.3)
put(1,'logging_tools','tool_rack',[790,3190])
put(1,'logging_wagon','broken_wagon',[620,3280],angle=-.55,footprint=[150,165])
put(1,'logging_rope','rope_coil',[800,3310])
for i,p in enumerate([(600,1850),(520,2000),(610,2200),(3890,1900),(3990,2100),(4080,2250),(4010,2760)]):
    put(1,f'field_strata_{i}','strata_outcrop',p,angle=.3+i*.19,scale=[1.1,.65+i%3*.25,.85])
put(1,'cave_waymark','road_shrine',[1130,2170])
put(1,'cave_drain','drain_channel',[1070,2360],angle=.8)
put(1,'cave_fallen_tree','fallen_oak',[590,2510],angle=.9)

# Roadside castle approach, visibly distinct from the rocky cave entrance.
put(2,'castle_approach_marker','road_shrine',[1400,1990])
put(2,'castle_abandoned_wagon','broken_wagon',[1540,2240],angle=-.3,footprint=[150,155])
put(2,'castle_approach_banner','castle_banner',[650,1890],reveal=True)
put(2,'castle_road_cargo','cargo',[1700,2320])
put(2,'castle_road_rubble','rubble',[580,2290],scale=[1.2,1.2,1.2])

# Supports frame the central passage, leaving the centre free for walking.
for i,p in enumerate([(2400,900),(1940,1290),(1080,1890),(2350,3040)]):
    put(7,f'mine_arch_{i}','mine_support',p,angle=0 if i%2==0 else .30,reveal=True,occlusion_height=255)
put(7,'mining_face','strata_outcrop',[470,2450],angle=1.3,scale=[.6,.7,.6])
put(7,'mining_cargo','cargo',[580,2550],scale=[.65,.65,.65],footprint=[85,90])
put(7,'mine_broken_wagon','broken_wagon',[3040,2850],angle=.45,footprint=[140,170])
put(7,'mine_deep_lamp','candle_cluster',[2820,3200])

# West arsenal, east clerks' wing, dry court, central hall, elevated lord's dais.
put(9,'court_dry_fountain','castle_fountain',[2080,1900],footprint=[250,250])
put(9,'court_ruined_cart','broken_wagon',[4500,1700],angle=.7,footprint=[160,170])
put(9,'court_supply_crates','cargo',[4350,1900],footprint=[110,110])
for i,y in enumerate([2640,3090,3540]):
    put(9,f'arsenal_rack_{i}','weapon_stand',[820,y],footprint=[110,65])
    put(9,f'arsenal_crate_{i}','cargo',[1540,y],scale=[.65,.65,.65],footprint=[80,80])
put(9,'arsenal_war_table','watch_map_table',[1120,3930],footprint=[135,95])
for i,y in enumerate([2690,3170,3700]):
    put(9,f'clerk_shelf_{i}','bookshelf',[5520,y],footprint=[120,60])
    put(9,f'clerk_lectern_{i}','archive_lectern',[4850,y],footprint=[105,60])
put(9,'clerk_scrolls','archive_scrolls',[5510,3950],footprint=[100,50])
for i,y in enumerate([3200,4000]):
    for side,x in enumerate([2700,3700]):
        put(9,f'hall_banner_{i}_{side}','castle_banner',[x,y],reveal=True)
put(9,'lord_throne','castle_throne',[3200,6190],footprint=[190,170])
for i,x in enumerate([2700,3700]):
    put(9,f'lord_candles_{i}','candle_cluster',[x,6080])
    put(9,f'lord_standard_{i}','castle_banner',[x,6260],reveal=True)
put(9,'west_gallery_debris','rubble',[1680,4320],scale=[1.1,.7,.8])
put(9,'east_gallery_cargo','cargo',[4630,4380],scale=[.8,.8,.8])
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('DRESSING', {k:len(v) for k,v in data['regions'].items()})
