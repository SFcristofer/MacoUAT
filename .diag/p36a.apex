PageReference p = new PageReference('/quote/quoteTemplateDataViewer.apexp?id=0Q0WD000006huxx0AA&headerHeight=180&footerHeight=10&summlid=0EHal0000020Tk0');
String h = p.getContent().toString();
System.debug('LEN|' + h.length());
for (String k : new List<String>{'1-E-2','7-H-3','Ubicaci','bicaci','Cantidad','Descripci'}) System.debug('HAS|' + k + '|' + h.contains(k));
