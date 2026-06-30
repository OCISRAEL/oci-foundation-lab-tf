DECLARE
  l_status     NUMBER;
  l_collection SODA_COLLECTION_T;
BEGIN
  -- Drop the incorrect collection if it exists.
  l_status := DBMS_SODA.DROP_COLLECTION('MY_COLLECTION');

  -- Recreate as MongoDB-compatible and empty.
  l_collection := DBMS_SODA.CREATE_COLLECTION(
    'MY_COLLECTION',
    '{
      "contentColumn"      : {"name"       : "DATA",
                              "sqlType"    : "BLOB",
                              "jsonFormat" : "OSON"},
      "keyColumn"          : {"name"             : "ID",
                              "assignmentMethod" : "EMBEDDED_OID",
                              "sqlType"          : "VARCHAR2"},
      "versionColumn"      : {"name" : "VERSION", "method" : "UUID"},
      "lastModifiedColumn" : {"name" : "LAST_MODIFIED"},
      "creationTimeColumn" : {"name" : "CREATED_ON"}
    }'
  );
END;
/
