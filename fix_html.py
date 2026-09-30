import sys
import re

try:
    with open('Pendientes_MACO_vs_UAT.html', 'r', encoding='utf-8') as f:
        content = f.read()

    # Reemplazar la fila 36
    pattern = re.compile(r'<tr><td>36</td><td>Mostrar la ubicación de los productos en el PDF de cotización.*?</td></tr>', re.DOTALL)
    replacement = '<tr><td>36</td><td>Mostrar la ubicación de los productos en el PDF de cotización (ya está en el de pedido)</td><td class="ok">✅</td><td>Campo Location agregado exitosamente a la plantilla estándar. Solucionado el 29-Sep.</td><td>Completado.</td></tr>'
    
    content = pattern.sub(replacement, content)

    with open('Pendientes_MACO_vs_UAT.html', 'w', encoding='utf-8') as f:
        f.write(content)
        
    print("HTML updated successfully.")
except Exception as e:
    print(f"Error: {e}")
