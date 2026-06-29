import urllib.request, json, sys

req = urllib.request.Request(
    'https://api.quran.com/api/v4/verses/by_key/2:44?words=true&word_fields=text_uthmani_tajweed,text_qpc_hafs', 
    headers={'User-Agent': 'curl'}
)
r = urllib.request.urlopen(req)
d = json.loads(r.read())
w = d['verse']['words'][0]

with open('out.txt', 'w', encoding='utf-8') as f:
    f.write(f"tajweed: {w['text_uthmani_tajweed']}\nhafs: {w['text_qpc_hafs']}\n")
