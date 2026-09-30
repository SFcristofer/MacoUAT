PermissionSet ps = new PermissionSet(
    Name = 'Acceso_Ubicacion_Cotizacion_Autom',
    Label = 'Acceso Ubicación Cotización'
);
insert ps;

FieldPermissions fp = new FieldPermissions(
    ParentId = ps.Id,
    SobjectType = 'QuoteLineItem',
    Field = 'QuoteLineItem.Ubicacion__c',
    PermissionsRead = true,
    PermissionsEdit = true
);
insert fp;

List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
for(User u : [SELECT Id FROM User WHERE IsActive = true AND Profile.UserType = 'Standard']) {
    assignments.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
}
if(!assignments.isEmpty()) {
    Database.insert(assignments, false); // false = AllOrNone
}
