import sys

path = r"C:\Users\crist\OneDrive\Documentos\Salesforce Technovalue Job\MacoUat\force-app\main\default\flows\Generar_Cotizacion.flow-meta.xml"

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update connector
content = content.replace(
"""        <connector>
            <targetReference>Crear_Registro_de_Oportunidad</targetReference>
        </connector>
        <fields>
            <name>Account</name>""",
"""        <connector>
            <targetReference>Obtener_Cuenta</targetReference>
        </connector>
        <fields>
            <name>Account</name>"""
)

# 2. Insert Obtener_Cuenta
content = content.replace(
"""    <processType>Flow</processType>
    <recordCreates>""",
"""    <processType>Flow</processType>
    <recordLookups>
        <name>Obtener_Cuenta</name>
        <label>Obtener Cuenta</label>
        <locationX>176</locationX>
        <locationY>242</locationY>
        <assignNullValuesIfNoRecordsFound>false</assignNullValuesIfNoRecordsFound>
        <connector>
            <targetReference>Crear_Registro_de_Oportunidad</targetReference>
        </connector>
        <filterLogic>and</filterLogic>
        <filters>
            <field>Id</field>
            <operator>EqualTo</operator>
            <value>
                <elementReference>Account.recordId</elementReference>
            </value>
        </filters>
        <getFirstRecordOnly>true</getFirstRecordOnly>
        <object>Account</object>
        <storeOutputAutomatically>true</storeOutputAutomatically>
    </recordLookups>
    <recordCreates>"""
)

# 3. Add Pricebook2Id
content = content.replace(
"""        <inputAssignments>
            <field>StageName</field>
            <value>
                <stringValue>Quote</stringValue>
            </value>
        </inputAssignments>
        <object>Opportunity</object>""",
"""        <inputAssignments>
            <field>Pricebook2Id</field>
            <value>
                <elementReference>Obtener_Cuenta.ListadePrecio__c</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>StageName</field>
            <value>
                <stringValue>Quote</stringValue>
            </value>
        </inputAssignments>
        <object>Opportunity</object>"""
)

# 4. Add Method_of_Payment__c
content = content.replace(
"""        <inputAssignments>
            <field>Name</field>
            <value>
                <elementReference>NombreCotizacionDefault</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>OpportunityId</field>""",
"""        <inputAssignments>
            <field>Method_of_Payment__c</field>
            <value>
                <elementReference>Obtener_Cuenta.TipoVenta__c</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Name</field>
            <value>
                <elementReference>NombreCotizacionDefault</elementReference>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>OpportunityId</field>"""
)

# 5. Fix locationYs
content = content.replace(
"""        <name>Crear_Registro_de_Oportunidad</name>
        <label>Crear Registro de Oportunidad</label>
        <locationX>176</locationX>
        <locationY>242</locationY>""",
"""        <name>Crear_Registro_de_Oportunidad</name>
        <label>Crear Registro de Oportunidad</label>
        <locationX>176</locationX>
        <locationY>350</locationY>"""
)

content = content.replace(
"""        <name>Crear_Registro_de_Cotizacion</name>
        <label>Crear Registro de Cotización</label>
        <locationX>176</locationX>
        <locationY>350</locationY>""",
"""        <name>Crear_Registro_de_Cotizacion</name>
        <label>Crear Registro de Cotización</label>
        <locationX>176</locationX>
        <locationY>458</locationY>"""
)

content = content.replace(
"""        <name>Navegar_a_la_Cotizacion</name>
        <label>Navegar a la Cotizacion</label>
        <locationX>176</locationX>
        <locationY>458</locationY>""",
"""        <name>Navegar_a_la_Cotizacion</name>
        <label>Navegar a la Cotizacion</label>
        <locationX>176</locationX>
        <locationY>566</locationY>"""
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Flow updated successfully")
