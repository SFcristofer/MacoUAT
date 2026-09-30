import re,zlib,sys
for f in sys.argv[1:]:
    b=open(f,'rb').read(); t=b''
    for s in re.findall(rb'stream\r?\n(.*?)\r?\nendstream',b,re.S):
        try: t+=zlib.decompress(s)
        except: pass
    txt=b''.join(re.findall(rb'\((.*?)\)\s*Tj',t))+b'|'+b''.join(re.findall(rb'\[(.*?)\]\s*TJ',t))
    print(f,len(b),[k for k in (b'Ubicaci',b'1-E-2',b'7-H-3',b'Cantidad') if k in txt or k in t])
