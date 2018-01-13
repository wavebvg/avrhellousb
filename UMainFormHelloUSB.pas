unit UMainFormHelloUSB;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, ComCtrls, Menus, ActnList, StdActns, LibUsbOop;

type
  TByteControls = array[0..7] of TCheckBox;

  TPortLetter = (bpA, bpB, bpC, bpD);

  TPortCode = type word;

  TPortCodes = array[TPortLetter] of TPortCode;

  TPortBytes = array[TPortLetter] of Byte;

const
  Bits: array[0..7] of Cardinal = (1, 2, 4, 8, 16, 32, 64, 128);

type

  { TUSBDevice }

  TUSBDevice = class(TComponent)
  private
    FTimerCheckActive: TTimer;
    FDevice: TLibUsbDevice;
    FContext: TLibUsbContext;
    FOnDisconnect: TNotifyEvent;
    FPID: Cardinal;
    FVID: Cardinal;
    function GetByte(const APortCode: TPortCode): Byte;
    function GetActive: Boolean;
    function GetPIN(const APort: TPortLetter): Byte;
    function GetPOUT(const APort: TPortLetter): Byte;
    procedure SetActive(const AValue: Boolean);
    procedure SetByte(const APortCode: TPortCode; const AValue: Byte);
    procedure SetPOUT(const APort: TPortLetter; const AValue: Byte);
    procedure DoDisconnect;
    procedure TimerCheckActiveTimer(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function Open: Boolean;
    procedure Close;

    property PINs[const APort: TPortLetter]: Byte read GetPIN;
    property POUTs[const APort: TPortLetter]: Byte read GetPOUT write SetPOUT;
  published
    property VID: Cardinal read FVID write FVID;
    property PID: Cardinal read FPID write FPID;
    property Active: Boolean read GetActive write SetActive;

    property OnDisconnect: TNotifyEvent read FOnDisconnect write FOnDisconnect;
  end;

  { TFormHelloUSB }

  TFormHelloUSB = class(TForm)
    CheckGroupPINs: TCheckGroup;
    CheckGroupPOUTs: TCheckGroup;
    MenuItemAbout: TMenuItem;
    ActionList: TActionList;
    CheckBoxLED: TCheckBox;
    CheckBoxPINsTimer: TCheckBox;
    EditPID: TEdit;
    EditVID: TEdit;
    EditProductName: TEdit;
    EditVendor: TEdit;
    MenuItemExit: TMenuItem;
    MenuItemFile: TMenuItem;
    FileExit: TFileExit;
    LabelVID: TLabel;
    LabelPID: TLabel;
    LabelProductName: TLabel;
    LabelVendorName: TLabel;
    LabelPortsCaption: TLabel;
    LabelPinsCaption: TLabel;
    MainMenu: TMainMenu;
    MenuItemHelp: TMenuItem;
    PanelPorts: TPanel;
    PanelDevice: TPanel;
    PanelPins: TPanel;
    TimerCheckPins: TTimer;
    TimerCheckDevices: TTimer;
    TrackBarPinsTimerInterval: TTrackBar;
    procedure CheckBoxLEDChange(Sender: TObject);
    procedure CheckGroupPINsItemClick(Sender: TObject; Index: Integer);
    procedure CheckGroupPOUTsItemClick(Sender: TObject; Index: Integer);
    procedure CheckBoxPINsTimerChange(Sender: TObject);
    procedure TimerCheckDevicesTimer(Sender: TObject);
    procedure TimerCheckPinsTimer(Sender: TObject);
    procedure TrackBarPinsTimerIntervalChange(Sender: TObject);
  private
    FDevice: TUSBDevice;
    FDeviceEnabled: Boolean;
    FPortBytes: TPortBytes;
    function CheckByteBit(const AValue: Byte; const ABit: Byte): Boolean;
    procedure DeviceDisconnect(Sender: TObject);
    function GetPortByte(const AIndexes: array of Boolean): Byte;
    function GetPOUT(const APort: TPortLetter): Byte;
    procedure SetDeviceEnabled(const AValue: Boolean);
    procedure SetPIN(const APort: TPortLetter; const AValue: Byte);
    procedure SetPOUT(const APort: TPortLetter; const AValue: Byte);
    procedure ReadPINs;
    procedure ReadPOUTs;
    procedure BackupPOUTs;
    procedure WritePOUTs;
    procedure Connect;
    procedure UpdatePINsTimerInterval;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;

    property DeviceEnabled: Boolean read FDeviceEnabled write SetDeviceEnabled;
    property PINs[const APort: TPortLetter]: Byte write SetPIN;
    property POUTs[const APort: TPortLetter]: Byte read GetPOUT write SetPOUT;
  end;

var
  FormHelloUSB: TFormHelloUSB;

implementation

uses
  LibUsb;

const
  RQ_IO_READ: Integer = $11;
  RQ_IO_WRITE: Integer = $12;

const
  BytePINCodes: TPortCodes = (
    {bpA} $19,
    {bpB} $16,
    {bpC} $13,
    {bpD} $10
    );

  BytePOUTCodes: TPortCodes = (
    {bpA} $1B,
    {bpB} $18,
    {bpC} $15,
    {bpD} $12
    );

function GetByteControls(const AControl0, AControl1, AControl2, AControl3, AControl4, AControl5,
  AControl6, AControl7: TCheckBox): TByteControls;
var
  i: Integer;
begin
  Result[0] := AControl0;
  Result[1] := AControl1;
  Result[2] := AControl2;
  Result[3] := AControl3;
  Result[4] := AControl4;
  Result[5] := AControl5;
  Result[6] := AControl6;
  Result[7] := AControl7;
  for i := Low(Result) to High(Result) do
    if Assigned(Result[i]) then
      Result[i].Tag := 1 shl i;
end;

function TUSBDevice.GetByte(const APortCode: TPortCode): Byte;
var
  VValue: TDynByteArray;
begin
  if Active then
    try
      VValue := FDevice.Control.ControlMsg(LIBUSB_ENDPOINT_IN or LIBUSB_REQUEST_TYPE_VENDOR or
        LIBUSB_RECIPIENT_DEVICE, RQ_IO_READ, 0, APortCode, 3, 300);
      if Length(VValue) > 0 then
        Result := VValue[0]
      else
        Result := 0;
    except
      on E: EUSBError do
        DoDisconnect;
    end
  else
    DoDisconnect;
end;

procedure TUSBDevice.SetByte(const APortCode: TPortCode; const AValue: Byte);
begin
  if Active then
    try
      FDevice.Control.ControlMsg(LIBUSB_ENDPOINT_OUT or LIBUSB_REQUEST_TYPE_VENDOR or
        LIBUSB_RECIPIENT_DEVICE, RQ_IO_WRITE, AValue, APortCode, 300);
    except
      on E: EUSBError do
        DoDisconnect;
    end
  else
    DoDisconnect;
end;

function TUSBDevice.GetPIN(const APort: TPortLetter): Byte;
begin
  Result := GetByte(BytePINCodes[APort]);
end;

function TUSBDevice.GetPOUT(const APort: TPortLetter): Byte;
begin
  Result := GetByte(BytePOUTCodes[APort]);
end;

procedure TUSBDevice.SetActive(const AValue: Boolean);
begin
  if AValue then
    if not Open then
    begin
      raise EUSBError.Create('Device not found');
    end
    else
      Close;
end;

procedure TUSBDevice.SetPOUT(const APort: TPortLetter; const AValue: Byte);
begin
  SetByte(BytePOUTCodes[APort], AValue);
end;

procedure TUSBDevice.DoDisconnect;
begin
  if Assigned(FOnDisconnect) then
    FOnDisconnect(Self);
end;

constructor TUSBDevice.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FContext := TLibUsbContext.Create;
  FTimerCheckActive := TTimer.Create(Self);
  FTimerCheckActive.Interval := 500;
  FTimerCheckActive.Enabled := False;
  FTimerCheckActive.OnTimer := @TimerCheckActiveTimer;
end;

procedure TUSBDevice.TimerCheckActiveTimer(Sender: TObject);
begin
  if not Active then
    DoDisconnect;
end;

destructor TUSBDevice.Destroy;
begin
  FContext.Free;
  inherited Destroy;
end;

function TUSBDevice.GetActive: Boolean;
begin
  Result := Assigned(FDevice) and FDevice.IsPresent;
end;

function TUSBDevice.Open: Boolean;
var
  VDevices: TLibUsbDeviceArray;
begin
  if not Active then
  begin
    FreeAndNil(FDevice);
    VDevices := FContext.FindDevices(VID, PID);
    Result := Length(VDevices) > 0;
    if Result then
    begin
      FDevice := TLibUsbDevice.Create(FContext, VID, PID);
      FTimerCheckActive.Enabled := Active;
    end;
  end
  else
    Result := True;
end;

procedure TUSBDevice.Close;
begin
  FreeAndNil(FDevice);
end;

{$R *.lfm}

{ TFormHelloUSB }

constructor TFormHelloUSB.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FDevice := TUSBDevice.Create(Self);
  FDevice.OnDisconnect := @DeviceDisconnect;
  FDevice.VID := $16c0;
  FDevice.PID := $05dc;
  Connect;
end;

destructor TFormHelloUSB.Destroy;
begin
  inherited Destroy;
end;

procedure TFormHelloUSB.DeviceDisconnect(Sender: TObject);
begin
  DeviceEnabled := False;
end;

procedure TFormHelloUSB.CheckGroupPOUTsItemClick(Sender: TObject; Index: Integer);
begin
  WritePOUTs;
end;

procedure TFormHelloUSB.CheckGroupPINsItemClick(Sender: TObject; Index: Integer);
begin
  CheckGroupPINs.Checked[Index] := not CheckGroupPINs.Checked[Index];
end;

procedure TFormHelloUSB.CheckBoxLEDChange(Sender: TObject);
begin
  WritePOUTs;
end;

procedure TFormHelloUSB.UpdatePINsTimerInterval;
begin
  TimerCheckPins.Interval := TrackBarPinsTimerInterval.Position;
end;

procedure TFormHelloUSB.CheckBoxPINsTimerChange(Sender: TObject);
begin
  TrackBarPinsTimerInterval.Enabled := CheckBoxPINsTimer.Checked;
  CheckGroupPINs.Enabled := CheckBoxPINsTimer.Checked;
  TimerCheckPins.Enabled := CheckBoxPINsTimer.Checked;
  UpdatePINsTimerInterval;
  ReadPINs;
end;

procedure TFormHelloUSB.TimerCheckDevicesTimer(Sender: TObject);
begin
  Connect;
end;

procedure TFormHelloUSB.TimerCheckPinsTimer(Sender: TObject);
begin
  ReadPINs;
end;

procedure TFormHelloUSB.WritePOUTs;
var
  VPort: TPortLetter;
begin
  for VPort := Low(VPort) to High(VPort) do
    if FPortBytes[VPort] <> POUTs[VPort] then
      FDevice.POUTs[VPort] := POUTs[VPort];
  ReadPOUTs;
end;

procedure TFormHelloUSB.Connect;
begin
  if FDevice.Open then
  begin
    ReadPINs;
    ReadPOUTs;
    DeviceEnabled := True;
  end
  else
    DeviceEnabled := False;
end;

procedure TFormHelloUSB.ReadPINs;
var
  VPort: TPortLetter;
begin
  for VPort := Low(VPort) to High(VPort) do
    if CheckBoxPINsTimer.Checked then
      PINs[VPort] := FDevice.PINs[VPort]
    else
      PINs[VPort] := 0;
end;

procedure TFormHelloUSB.ReadPOUTs;
var
  VPort: TPortLetter;
begin
  for VPort := Low(VPort) to High(VPort) do
    POUTs[VPort] := FDevice.POUTs[VPort];
  BackupPOUTs;
end;

procedure TFormHelloUSB.BackupPOUTs;
var
  VPort: TPortLetter;
begin
  for VPort := Low(VPort) to High(VPort) do
    FPortBytes[VPort] := POUTs[VPort];
end;

function TFormHelloUSB.GetPortByte(const AIndexes: array of Boolean): Byte;
var
  i: Byte;
begin
  Result := 0;
  for i := 0 to 7 do
    if AIndexes[i] then
      Result += 1 shl i;
end;

procedure TFormHelloUSB.TrackBarPinsTimerIntervalChange(Sender: TObject);
begin
  UpdatePINsTimerInterval;
end;

function TFormHelloUSB.GetPOUT(const APort: TPortLetter): Byte;
begin
  case APort of
    bpA:
      Result := GetPortByte([CheckGroupPOUTs.Checked[1], CheckGroupPOUTs.Checked[0],
        CheckGroupPOUTs.Checked[3], CheckGroupPOUTs.Checked[2], CheckGroupPOUTs.Checked[5],
        CheckGroupPOUTs.Checked[4], CheckGroupPOUTs.Checked[7], CheckGroupPOUTs.Checked[6]]);
    bpB:
      Result := GetPortByte([CheckBoxLED.Checked, CheckGroupPOUTs.Checked[9], CheckGroupPOUTs.Checked[8],
        CheckGroupPOUTs.Checked[11], CheckGroupPOUTs.Checked[10], False, False, False]);
    bpC:
      Result := GetPortByte([CheckGroupPOUTs.Checked[13], CheckGroupPOUTs.Checked[12], False,
        False, False, False, CheckGroupPOUTs.Checked[15], CheckGroupPOUTs.Checked[14]]);
    bpD:
      Result := GetPortByte([CheckGroupPOUTs.Checked[17], CheckGroupPOUTs.Checked[16], False,
        CheckGroupPOUTs.Checked[19], False, CheckGroupPOUTs.Checked[18], CheckGroupPOUTs.Checked[21],
        CheckGroupPOUTs.Checked[20]]);
  end;
end;

procedure TFormHelloUSB.SetDeviceEnabled(const AValue: Boolean);
begin
  if FDeviceEnabled = AValue then
    Exit;
  FDeviceEnabled := AValue;
  TimerCheckDevices.Enabled := not DeviceEnabled;
  CheckBoxLED.Enabled := DeviceEnabled;
  CheckGroupPOUTs.Enabled := DeviceEnabled;
  CheckBoxPINsTimer.Enabled := DeviceEnabled;
  CheckBoxPINsTimer.Checked := False;
end;

function TFormHelloUSB.CheckByteBit(const AValue: Byte; const ABit: Byte): Boolean;
begin
  Result := AValue and Bits[ABit] > 0;
end;

procedure TFormHelloUSB.SetPIN(const APort: TPortLetter; const AValue: Byte);
begin
  case APort of
    bpA:
    begin
      CheckGroupPINs.Checked[1] := CheckByteBit(AValue, 0);
      CheckGroupPINs.Checked[0] := CheckByteBit(AValue, 1);
      CheckGroupPINs.Checked[3] := CheckByteBit(AValue, 2);
      CheckGroupPINs.Checked[2] := CheckByteBit(AValue, 3);
      CheckGroupPINs.Checked[5] := CheckByteBit(AValue, 4);
      CheckGroupPINs.Checked[4] := CheckByteBit(AValue, 5);
      CheckGroupPINs.Checked[7] := CheckByteBit(AValue, 6);
      CheckGroupPINs.Checked[6] := CheckByteBit(AValue, 7);
    end;
    bpB:
    begin
      CheckGroupPINs.Checked[9] := CheckByteBit(AValue, 1);
      CheckGroupPINs.Checked[8] := CheckByteBit(AValue, 2);
      CheckGroupPINs.Checked[11] := CheckByteBit(AValue, 3);
      CheckGroupPINs.Checked[10] := CheckByteBit(AValue, 4);
    end;
    bpC:
    begin
      CheckGroupPINs.Checked[13] := CheckByteBit(AValue, 0);
      CheckGroupPINs.Checked[12] := CheckByteBit(AValue, 1);
      CheckGroupPINs.Checked[15] := CheckByteBit(AValue, 6);
      CheckGroupPINs.Checked[14] := CheckByteBit(AValue, 7);
    end;
    bpD:
    begin
      CheckGroupPINs.Checked[17] := CheckByteBit(AValue, 0);
      CheckGroupPINs.Checked[16] := CheckByteBit(AValue, 1);
      CheckGroupPINs.Checked[19] := CheckByteBit(AValue, 3);
      CheckGroupPINs.Checked[18] := CheckByteBit(AValue, 5);
      CheckGroupPINs.Checked[21] := CheckByteBit(AValue, 6);
      CheckGroupPINs.Checked[20] := CheckByteBit(AValue, 7);
    end;
  end;
end;

procedure TFormHelloUSB.SetPOUT(const APort: TPortLetter; const AValue: Byte);
begin
  case APort of
    bpA:
    begin
      CheckGroupPOUTs.Checked[1] := CheckByteBit(AValue, 0);
      CheckGroupPOUTs.Checked[0] := CheckByteBit(AValue, 1);
      CheckGroupPOUTs.Checked[3] := CheckByteBit(AValue, 2);
      CheckGroupPOUTs.Checked[2] := CheckByteBit(AValue, 3);
      CheckGroupPOUTs.Checked[5] := CheckByteBit(AValue, 4);
      CheckGroupPOUTs.Checked[4] := CheckByteBit(AValue, 5);
      CheckGroupPOUTs.Checked[7] := CheckByteBit(AValue, 6);
      CheckGroupPOUTs.Checked[6] := CheckByteBit(AValue, 7);
    end;
    bpB:
    begin
      CheckBoxLED.Checked := CheckByteBit(AValue, 0);
      CheckGroupPOUTs.Checked[9] := CheckByteBit(AValue, 1);
      CheckGroupPOUTs.Checked[8] := CheckByteBit(AValue, 2);
      CheckGroupPOUTs.Checked[11] := CheckByteBit(AValue, 3);
      CheckGroupPOUTs.Checked[10] := CheckByteBit(AValue, 4);
    end;
    bpC:
    begin
      CheckGroupPOUTs.Checked[13] := CheckByteBit(AValue, 0);
      CheckGroupPOUTs.Checked[12] := CheckByteBit(AValue, 1);
      CheckGroupPOUTs.Checked[15] := CheckByteBit(AValue, 6);
      CheckGroupPOUTs.Checked[14] := CheckByteBit(AValue, 7);
    end;
    bpD:
    begin
      CheckGroupPOUTs.Checked[17] := CheckByteBit(AValue, 0);
      CheckGroupPOUTs.Checked[16] := CheckByteBit(AValue, 1);
      CheckGroupPOUTs.Checked[19] := CheckByteBit(AValue, 3);
      CheckGroupPOUTs.Checked[18] := CheckByteBit(AValue, 5);
      CheckGroupPOUTs.Checked[21] := CheckByteBit(AValue, 6);
      CheckGroupPOUTs.Checked[20] := CheckByteBit(AValue, 7);
    end;
  end;
end;

end.
