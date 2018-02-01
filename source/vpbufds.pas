{ Visual PlanIt datastore for a TBufDataset }

{$I vp.inc}

unit VpBufDS;

interface

uses
  SysUtils, Classes, db, BufDataset,
  VpDBDS;

type

  { TVpBufDSDataStore }

  TVpBufDSDataStore = class(TVpCustomDBDataStore)
  private
    FResourceTable: TBufDataset;
    FEventsTable: TBufDataset;
    FContactsTable: TBufDataset;
    FTasksTable: TBufDataset;
    FDirectory: String;
    FUseAutoInc: Boolean;
    FPersistent: Boolean;
    procedure SetDirectory(AValue: String);
    procedure SetPersistent(AValue: Boolean);
    procedure SetUseAutoInc(AValue: Boolean);

  protected
    { ancestor property getters }
    function GetContactsTable: TDataset; override;
    function GetEventsTable: TDataset; override;
    function GetResourceTable: TDataset; override;
    function GetTasksTable: TDataset; override;

    { ancestor methods }
    procedure Loaded; override;
    procedure SetConnected(const Value: boolean); override;

    { other methods }
    procedure CloseTables;
    procedure CreateTable(ATableName: String);
    procedure OpenTables;
    function UniqueID(AValue: Integer): Boolean;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure CreateTables;
    function GetNextID(TableName: string): Int64; override;

    property ResourceTable;
    property EventsTable;
    property ContactsTable;
    property TasksTable;

  published
    property AutoConnect;
    property AutoCreate;
    property DayBuffer;
    property Directory: String read FDirectory write SetDirectory;
    property Persistent: Boolean read FPersistent write SetPersistent default true;
    property UseAutoIncFields: Boolean read FUseAutoInc write SetUseAutoInc default true;
  end;


implementation

uses
  LazFileUtils,
  VpConst, VpMisc, VpBaseDS, VpData;

const
  TABLE_EXT = '.db';

constructor TVpBufDSDataStore.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FResourceTable := TBufDataset.Create(nil);
  FEventsTable := TBufDataset.Create(nil);
  FContactsTable := TBufDataset.Create(nil);
  FTasksTable := TBufDataset.Create(nil);
  FPersistent := true;
  FUseAutoInc := true;
end;

destructor TVpBufDSDataStore.Destroy;
begin
  FreeAndNil(FResourceTable);
  FreeAndNil(FEventsTable);
  FreeAndNil(FContactsTable);
  FreeAndNil(FTasksTable);
  inherited;
end;

procedure TVpBufDSDataStore.CloseTables;
begin
  FResourceTable.Close;
  FEventsTable.Close;
  FContactsTable.Close;
  FTasksTable.Close;
end;

procedure TVpBufDSDataStore.CreateTable(ATableName: String);
var
  dir: String;
  table: TBufDataset;
begin
  if FDirectory = '' then
    dir := ExtractFilePath(ParamStr(0)) else
    dir := IncludeTrailingPathDelimiter(FDirectory);
  dir := ExpandFileName(dir);
  if not DirectoryExistsUTF8(dir) then
  begin
    if AutoCreate then
      CreateDir(dir)
    else
      raise Exception.CreateFmt('Directory "%s" for tables does not exist.', [dir]);
  end;

  if ATableName = ResourceTableName then
    table := FResourceTable
  else if ATableName = EventsTableName then
    table := FEventsTable
  else if ATableName = ContactsTablename then
    table := FContactsTable
  else if ATableName = TasksTableName then
    table := FTasksTable
  else
    raise Exception.CreateFmt('TableName "%s" cannot be processed.', [ATableName]);

  table.Close;
  if FPersistent then
    table.FileName := dir + ATableName + TABLE_EXT;
  if ((not FPersistent) or (not FileExists(table.FileName))) and (table.FieldDefs.Count = 0) then
  begin
     CreateFieldDefs(ATableName, table.FieldDefs);
     if FUseAutoInc then
       table.FieldDefs[0].DataType := ftAutoInc;
     table.CreateDataset;
  end;
  table.IndexDefs.Clear;
  table.IndexDefs.Update;
  CreateIndexDefs(ATableName, table.IndexDefs);
end;

procedure TVpBufDSDataStore.CreateTables;
begin
  CreateTable(ResourceTablename);
  CreateTable(EventsTableName);
  CreateTable(ContactsTableName);
  CreateTable(TasksTableName);
end;

function TVpBufDSDataStore.GetResourceTable: TDataset;
begin
  Result := FResourceTable;
end;

function TVpBufDSDataStore.GetEventsTable: TDataset;
begin
  Result := FEventsTable;
end;

function TVpBufDSDataStore.GetContactsTable: TDataset;
begin
  Result := FContactsTable;
end;

function TVpBufDSDataStore.GetNextID(TableName: string): Int64;
begin
  Unused(TableName);
  if FUseAutoInc then
    { This is not needed in the BufDataset datastore as these tables use
      autoincrement fields. }
    Result := -1
  else
    { If autoincrement fields are not wanted the ID values are created from
      random numbers. }
    repeat
      Result := Random(High(Integer));
    until UniqueID(Result) and (Result <> -1);
end;

function TVpBufDSDataStore.GetTasksTable: TDataset;
begin
  Result := FTasksTable;
end;

procedure TVpBufDSDataStore.Loaded;
begin
  inherited;
  Connected := AutoConnect;
end;

procedure TVpBufDSDataStore.OpenTables;
begin
  FResourceTable.Open;
  FEventsTable.Open;
  FContactsTable.Open;
  FTasksTable.Open;
end;

procedure TVpBufDSDataStore.SetConnected(const Value: boolean);
begin
  { Don't do anything with live data until run time. }
  if (csDesigning in ComponentState) or (csLoading in ComponentState) then
    Exit;

  { Connecting or disconnecting? }
  if Value then begin
    if AutoCreate then CreateTables;
    OpenTables;
    Load;
  end;

  inherited SetConnected(Value);
end;

procedure TVpBufDSDataStore.SetDirectory(AValue: String);
begin
  if AValue = FDirectory then
    exit;
  if Connected then
    raise Exception.Create('Set directory before connecting.');
  FDirectory := AValue;
end;

procedure TVpBufDSDataStore.SetPersistent(AValue: Boolean);
var
  wasConn: Boolean;
begin
  if AValue <> FPersistent then begin
    wasConn := Connected;
    Connected := false;
    FPersistent := AValue;
    if not FPersistent then begin
      FResourceTable.FileName := '';
      FEventsTable.FileName := '';
      FContactsTable.FileName := '';
      FTasksTable.FileName := '';
    end;
    Connected := wasConn;
  end;
end;

procedure TVpBufDSDataStore.SetUseAutoInc(AValue: Boolean);
var
  dir: String;
begin
  if AValue = FUseAutoInc then
    exit;

  if ComponentState = [] then begin
    if FDirectory = '' then
      dir := ExtractFilePath(ParamStr(0)) else
      dir := IncludeTrailingPathDelimiter(FDirectory);
    dir := ExpandFileName(dir);
    if DirectoryExistsUTF8(dir) then
    begin
      if FileExists(dir + ResourceTableName + TABLE_EXT) or
         FileExists(dir + EventsTableName + TABLE_EXT) or
         FileExists(dir + ContactsTableName + TABLE_EXT) or
         FileExists(dir + TasksTableName + TABLE_EXT)
      then
        raise Exception.Create('You cannot change the property "UseAutoIncFields" after creation of the tables.');
    end;
  end;

  FUseAutoInc := AValue;
end;

function TVpBufDSDataStore.UniqueID(AValue: Integer): Boolean;
var
  i, j: Integer;
  res: TVpResource;
begin
  Result := false;
  for i:=0 to Resources.Count-1 do begin
    res := Resources.Items[i];
    if res.ResourceID = AValue then
      exit;
    for j:=0 to res.Contacts.Count-1 do
      if res.Contacts.GetContact(j).RecordID = AValue then
        exit;
    for j:=0 to res.Tasks.Count-1 do
      if res.Tasks.GetTask(j).RecordID = AValue then
        exit;
    for j:=0 to res.Schedule.EventCount-1 do
      if res.Schedule.GetEvent(j).RecordID = AValue then
        exit;
  end;
  Result := true;
end;

end.
