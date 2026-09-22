from pathlib import Path
out = Path(__file__).resolve().parents[1]/'assets/icons'
out.mkdir(exist_ok=True)
shapes = {
'crystal': ('#ef8293', '<path d="M32 4 50 22 43 49 29 61 13 40 17 17Z" fill="url(#g)"/><path d="m32 4-4 24 22-6M28 28l1 33 14-12M28 28 13 40M17 17l11 11" fill="none" stroke="#ffd1d3" stroke-width="1.3"/><path d="m32 9-6 12-3 14" stroke="#fff0e6" opacity=".8" fill="none"/>'),
'medicine': ('#92ddc7','<path d="M24 5h16v11H24z" fill="#d1c5b4"/><path d="M22 15h20v6l5 7v29q-15 7-30 0V28l5-7Z" fill="url(#g)"/><path d="M19 40h26v16q-13 5-26 0Z" fill="#426f68"/><path d="M29 29h6v6h6v6h-6v7h-6v-7h-6v-6h6z" fill="#dceade"/><path d="M23 25v26" stroke="#dcffed" opacity=".55" stroke-width="2"/>'),
'relic': ('#e3bd73','<path d="m32 3 6 10 11 6-4 9 12 5-12 7 2 12-15 9-15-9 2-12-12-7 12-5-4-9 11-6Z" fill="url(#g)"/><path d="m32 11 15 21-15 22-15-22Z" fill="#342334" stroke="#f7d88f"/><path d="m32 20 8 12-8 15-8-15Z" fill="#a93a53" stroke="#dc7984"/><path d="M32 2v10M5 33h13m28 0h13M32 53v9" stroke="#fff0bd" stroke-width="2"/>'),
'charm': ('#cbb3ee','<circle cx="32" cy="31" r="21" fill="#242133" stroke="#a3a3b8" stroke-width="3"/><path d="m32 5 6 12-6 38-6-38Z" fill="url(#g)"/><path d="M31 28 6 14l7 21 16 9 2-10M33 28l25-14-7 21-16 9-2-10" fill="url(#g)"/><path d="m32 24 8 6-8 9-8-9Z" fill="#b68cde" stroke="#efdeff"/><path d="M29 54h6v7h-6z" fill="#c1b4d2"/>'),
'ammo': ('#d0ac74','<path d="m10 17 9-11 8 11v35H10Zm18 3 8-11 8 11v35H28Zm18-3 8-11 7 11v35H46Z" fill="url(#g)" stroke="#e4cda6"/><path d="M8 32h54v26H8Z" fill="#454047" stroke="#a99479"/><path d="M14 38h42v13H14Z" fill="#645647"/><path d="M22 34v23m27-23v23" stroke="#b59a70" stroke-width="3"/>'),
'scrap': ('#b4b9c9','<path d="m25 5 14 0 2 9 7 4 9-2 6 12-8 6v7l5 8-10 10-9-5-7 2-5 8-14-5v-10l-5-6-10-1V28l9-4 5-6Z" fill="url(#g)"/><circle cx="32" cy="34" r="12" fill="#292b38" stroke="#d0cccb" stroke-width="3"/><path d="m29 22 4 9 9 5" stroke="#79717b" fill="none"/>'),
'armor': ('#bdc2d0','<path d="m20 8 12 6 12-6 14 12-9 14-7-5 4 29H18l4-29-7 5-9-14Z" fill="url(#g)"/><path d="m32 15-7 20 7 21 7-21Z" fill="#813749"/><path d="M18 42h28M14 18l9 9m27-9-9 9" stroke="#efddbc" stroke-width="2"/>'),
'rifle': ('#c5b0a1','<path d="m7 49 7 8 12-14 10 4 4-6-6-6 20-21-4-5-22 22-8-1Z" fill="url(#g)"/><path d="m45 14 13-12 4 4-13 13M27 25l-4-4 6-6 4 4" stroke="#e3d6c8" stroke-width="3"/><path d="m19 38 8 7-12 14-7-7Z" fill="#6d3845"/>'),
'boots': ('#c0a3b5','<path d="m24 5 25 4-8 31 10 11-3 9H12l-1-10 17-13Z" fill="url(#g)"/><path d="m26 13 19 4M24 23l18 4M25 34l14 3M12 52h35" stroke="#e4d7bf" stroke-width="2"/><path d="m26 8 4 28-5 11-9 6" fill="none" stroke="#785262" stroke-width="4"/>'),
'heart': ('#e096a5','<path d="M32 55C-5 33 3 7 19 9q9 0 13 9 4-9 13-9c16-2 24 24-13 46Z" fill="url(#g)"/><path d="m10 31 12 0 5-11 7 24 6-13h14" fill="none" stroke="#ffe4d3" stroke-width="2"/>'),
'skill': ('#d8b4d8','<path d="m32 2 8 20 22 10-22 8-8 22-8-22-22-8 22-10Z" fill="url(#g)"/><path d="m32 14 9 18-9 18-9-18Z" fill="#942e56" stroke="#f5d5ec"/><circle cx="32" cy="32" r="25" fill="none" stroke="#c8abb4" stroke-width="1"/>')
}
for name,(color,body) in shapes.items():
    svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{color}"/><stop offset=".47" stop-color="{color}"/><stop offset="1" stop-color="#393040"/></linearGradient></defs><g stroke="#302633" stroke-width="1.2" stroke-linejoin="round">{body}</g></svg>'''
    (out/f'{name}.svg').write_text(svg,encoding='utf-8')
