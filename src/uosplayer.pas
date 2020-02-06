unit UosPlayer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, uos_flat, ctypes;


{EQ}
type
equalizer_band_type = record
 lo_freq, hi_freq: integer;
 Text: string[10];
 end;

type
 { Events }
  TSampleFormat = (sfFloat32, sfInt32, sfInt16);
  TLogPlayerEvent = procedure(Log: string) of object;
  TOnPlayningEvent = procedure(PositionLength: cint32; PositionTime: ttime) of object;
  TOnBandLevelEvent = procedure(BabdArray : array of cfloat) of object;
  TOnShowLevelEvent = procedure(LeftLevel,RightLevel: Double) of object;

 { TUosPlayer }
  TUosPlayer = class(TComponent)
  private


    FFileName: String;
    FLength: cint32;
    FLengthTime: ttime;
    FLibPath: string;

    FOnLoadLib: TNotifyEvent;
    FOnLog: TLogPlayerEvent;
    FOnPause: TNotifyEvent;
    FOnPlay: TNotifyEvent;
    FOnPlayning: TOnPlayningEvent;
    FOnBandLevel: TOnBandLevelEvent;
    FOnResume: TNotifyEvent;
    FOnShowLevel: TOnShowLevelEvent;
    FOnStop: TNotifyEvent;
    FOnTrackEnd: TNotifyEvent;
    FPlayerIndex: integer;
    FOutputIndex: integer;
    FInputIndex: integer;
    FSampleFormat: TSampleFormat;
    FUosLoad: boolean;

    FLibPortaudio: string;
    FLibSndFile: string;
    FLibMpg123: string;
    FLibMp4ff: string;
    FLibFaad2: string;
    FLibOpusFile: string;

    FVolume_L: integer;
    FVolume_R: integer;



    procedure SetLibPath(AValue: string);

    procedure SetSampleFormat(AValue: TSampleFormat);
    procedure SetVolume(AValue: integer);
  protected
    procedure SetFileName(const Value: String); virtual;
    procedure LoadUos;
    procedure LoopProcPlayer;
    procedure ClosePlayer;
    function IsValidUrl(aUrl: String): Boolean;
  public
    Equalizer_Bands: array[1..10] of equalizer_band_type;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure InitPlayer;
    procedure Play;
    procedure Seek(Position: Tcount_t);
    procedure SeekSeconds(Position: cfloat);
    procedure SeekTime(Position: ttime);
    procedure SetEQ(EQIndex:integer;Gain:double;Enable:boolean);
    //    uos_InputSetFilter(PlayerIndex1, In1Index, EQIndex1, -1, -1, Gain, -1, True,
    //  checkbox1.Checked, nil);
    procedure Pause;
    procedure Resume;
    procedure Stop;
    function GetPlayerStatus: cint32;
    //-1 => error,  0 => has stopped, 1 => is running, 2 => is paused.
    function GetTagTitle:string;
    function GetTagArtist:string;
    function GetTagAlbum:string;
    function GetTagDate:string;
    function GetTagComment:string;
    function GetIceCastTitle:string;
    function UpdateTag:boolean;


  published
    property SampleFormat: TSampleFormat read FSampleFormat write SetSampleFormat;

    property LibPath: string read FLibPath write SetLibPath;
    property FileName: String read FFileName write SetFileName;


    property Volume_L: integer read FVolume_L write SetVolume;
    property Volume_R: integer read FVolume_R write SetVolume;


    property Length: cint32 read FLength;
    property LengthTime: ttime read FLengthTime;

    property OnLoadLib: TNotifyEvent read FOnLoadLib write FOnLoadLib;
    property OnPlay: TNotifyEvent read FOnPlay write FOnPlay;
    property OnPlayning: TOnPlayningEvent read FOnPlayning write FOnPlayning;
    property OnBandLevel: TOnBandLevelEvent read FOnBandLevel write FOnBandLevel;
    property OnShowLevel: TOnShowLevelEvent read FOnShowLevel write FOnShowLevel;
    property OnPause: TNotifyEvent read FOnPause write FOnPause;
    property OnResume: TNotifyEvent read FOnResume write FOnResume;
    property OnStop: TNotifyEvent read FOnStop write FOnStop;
    property OnTrackEnd:  TNotifyEvent read FOnTrackEnd write FOnTrackEnd;
    property OnLog: TLogPlayerEvent read FOnLog write FOnLog;

  end;

procedure Register;

implementation
uses RegExpr;

procedure Register;
begin
  {$I uosplayer_icon.lrs}
  RegisterComponents('Media', [TUosPlayer]);
end;

{ TUosPlayer }

procedure TUosPlayer.SetLibPath(AValue: string);
begin
  if FLibPath = AValue then
    Exit;
  FLibPath := AValue;
end;

procedure TUosPlayer.SetSampleFormat(AValue: TSampleFormat);
begin
  if FSampleFormat = AValue then
    Exit;
  FSampleFormat := AValue;
end;

procedure TUosPlayer.SetVolume(AValue: integer);
begin
  if AValue <= 100 then
  begin
    FVolume_L := AValue;
    FVolume_R := AValue;
    uos_InputSetDSPVolume(FPlayerIndex, FInputIndex, FVolume_L / 100,FVolume_R / 100, True);
  end
  else
   begin
    FVolume_L := 100;
    FVolume_R := 100;
   end;
end;

procedure TUosPlayer.SetFileName(const Value: String);
begin
  if FFilename=Value then exit;
  FFileName := Value;
end;

procedure TUosPlayer.LoadUos;
begin
  {$if defined(cpu64) and defined(linux) }
  FLibPortaudio := FLibPath + 'LibPortaudio-64.so';
  FLibSndFile   := FLibPath + 'LibSndFile-64.so';
  FLibMpg123    := FLibPath + 'LibMpg123-64.so';
  FLibMp4ff     := FLibPath + 'LibMp4ff-64.so';
  FLibFaad2     := FLibPath + 'LibFaad2-64.so';
  FLibOpusFile  := FLibPath + 'LibOpusFile-64.so';
  {$ENDIF}
  if uos_LoadLib(PChar(FLibPortaudio), PChar(FLibSndFile),
    PChar(FLibMpg123), PChar(FLibMp4ff), PChar(FLibFaad2), PChar(FLibOpusFile)) = 0 then
  begin
    FUosLoad := True;
    if Assigned(FOnLoadLib) then
      FOnLoadLib(Self);
    if Assigned(FOnLog) then
      FOnLog('PortAudio, SndFile, Mpg123, AAC, Opus libraries are loaded...');
  end
  else
  if Assigned(FOnLog) then
    FOnLog('Error while loading libraries...');

  Equalizer_Bands[1].lo_freq := 18;
  Equalizer_Bands[1].hi_freq := 46;
  Equalizer_Bands[1].Text := '31';
  Equalizer_Bands[2].lo_freq := 47;
  Equalizer_Bands[2].hi_freq := 94;
  Equalizer_Bands[2].Text := '62';
  Equalizer_Bands[3].lo_freq := 95;
  Equalizer_Bands[3].hi_freq := 188;
  Equalizer_Bands[3].Text := '125';
  Equalizer_Bands[4].lo_freq := 189;
  Equalizer_Bands[4].hi_freq := 375;
  Equalizer_Bands[4].Text := '250';
  Equalizer_Bands[5].lo_freq := 376;
  Equalizer_Bands[5].hi_freq := 750;
  Equalizer_Bands[5].Text := '500';
  Equalizer_Bands[6].lo_freq := 751;
  Equalizer_Bands[6].hi_freq := 1500;
  Equalizer_Bands[6].Text := '1K';
  Equalizer_Bands[7].lo_freq := 1501;
  Equalizer_Bands[7].hi_freq := 3000;
  Equalizer_Bands[7].Text := '2K';
  Equalizer_Bands[8].lo_freq := 3001;
  Equalizer_Bands[8].hi_freq := 6000;
  Equalizer_Bands[8].Text := '4K';
  Equalizer_Bands[9].lo_freq := 6001;
  Equalizer_Bands[9].hi_freq := 12000;
  Equalizer_Bands[9].Text := '8K';
  Equalizer_Bands[10].lo_freq := 12001;
  Equalizer_Bands[10].hi_freq := 20000;
  Equalizer_Bands[10].Text := '16K';
end;

procedure TUosPlayer.LoopProcPlayer;
begin
  if Assigned(FOnPlayning) then
  begin
    FOnPlayning(uos_InputPosition(FPlayerIndex, FInputIndex),
      uos_InputPositionTime(FPlayerIndex, FInputIndex));
  end;
  if Assigned(FOnBandLevel) then
   begin
     FOnBandLevel(uos_InputFiltersGetLevelArray(FPlayerIndex,FInputIndex));
   end;
  if Assigned(FOnShowLevel) then
   begin
     FOnShowLevel(uos_InputGetLevelLeft(FPlayerIndex,FInputIndex),
     uos_InputGetLevelRight(FPlayerIndex,FInputIndex));
   end;
end;

procedure TUosPlayer.ClosePlayer;
begin
  if Assigned(FOnTrackEnd) then FOnTrackEnd(Self);
end;

function TUosPlayer.IsValidUrl(aUrl: String): Boolean;
var
  aRegEx: TRegexpr;
  aExpr: String;
begin
  aExpr := '(http(s)?:\/\/.)?(www\.)?[a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([a-zA-Z0-9@:%_\+.~#?&//=]*)';

  aRegEx := TRegexpr.Create;
  aRegEx.Expression := aExpr;
  aRegEx.ModifierG;
  try
    Result := aRegEx.Exec(aUrl);
  finally
    aRegEx.Free;
  end;
end;



constructor TUosPlayer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FUosLoad := False;
  FVolume_L := 100;
  FVolume_R := 100;
end;

destructor TUosPlayer.Destroy;
begin
  uos_free;
  inherited Destroy;
end;

procedure TUosPlayer.InitPlayer;
begin
  LoadUos;
end;

procedure TUosPlayer.Play;
var
  samformat: shortint;
  i: integer;
begin
  if uos_GetStatus(FPlayerIndex) > 0 then
    Stop;

  case FSampleFormat of
    sfFloat32: samformat := 0;
    sfInt32: samformat := 1;
    sfInt16: samformat := 2;
  end;

  FInputIndex := -1;

  if (FUosLoad and FileExists(FFileName)) or (FUosLoad and IsValidUrl(FFileName)) then
  begin
    FPlayerIndex := 0;

    if uos_CreatePlayer(FPlayerIndex) then
    if IsValidUrl(FFilename) then
    begin
    FInputIndex :=  uos_AddFromURL(FPlayerIndex, Pchar(FFileName),-1,samformat,-1, 0, false) ;
                                                                                  {0-mp3,1-opus}
     end else
     FInputIndex := uos_AddFromFile(FPlayerIndex, PChar(FFileName),-1, samformat, -1);




    if FInputIndex <> - 1 then
    begin
     {$if defined(cpuarm)}// needs lower latency
      // todo надо как то купить малинку
        FOutputIndex := uos_AddIntoDevOut(FPlayerIndex, -1, 0.3,
        uos_InputGetSampleRate(FPlayerIndex, FInputIndex),
        uos_InputGetChannels(FPlayerIndex, FInputIndex), samformat, -1, -1);
     {$else}
        FOutputIndex := uos_AddIntoDevOut(FPlayerIndex, -1, -1,
        uos_InputGetSampleRate(FPlayerIndex, FInputIndex),
        uos_InputGetChannels(FPlayerIndex, FInputIndex), samformat, -1, -1);
     {$endif}
      uos_InputSetLevelEnable(FPlayerIndex, FInputIndex, 2);
      uos_InputSetPositionEnable(FPlayerIndex, FInputIndex, 1);
      uos_LoopProcIn(FPlayerIndex, FInputIndex, @LoopProcPlayer);
      uos_EndProc(FPlayerIndex, @ClosePlayer);

      uos_InputAddDSPVolume(FPlayerIndex, FInputIndex, 1, 1);
      uos_InputSetDSPVolume(FPlayerIndex, FInputIndex, FVolume_L/100,FVolume_R/100,True); /// Set volume


      ///
           if FOutputIndex > -1 then
    begin
      for i := 1 to 10 do
      uos_InputAddFilter(FPlayerIndex, FInputIndex, Equalizer_Bands[i].lo_freq, Equalizer_Bands[i].hi_freq, 1, 3, False, nil);
    end;



    uos_Play(FPlayerIndex);

      FLength := uos_InputLength(FPlayerIndex, FInputIndex);
      FLengthTime := uos_InputLengthTime(FPlayerIndex, FInputIndex);

      if Assigned(FOnPlay) then FOnPlay(Self);
      if Assigned(FOnLog) then FOnLog('Playning ....');
    end
    else
    if Assigned(FOnLog) then FOnLog('Unable to open');
  end;

end;

procedure TUosPlayer.Seek(Position: Tcount_t);
begin
  uos_InputSeek(FPlayerIndex, FInputIndex, Position);
end;

procedure TUosPlayer.SeekSeconds(Position: cfloat);
begin
  uos_InputSeekSeconds(FPlayerIndex, FInputIndex, Position);
end;

procedure TUosPlayer.SeekTime(Position: ttime);
begin
  uos_InputSeekTime(FPlayerIndex, FInputIndex, Position);
end;

procedure TUosPlayer.SetEQ(EQIndex: integer; Gain: double; Enable: boolean);
begin
   uos_InputSetFilter(FPlayerIndex, FInputIndex, EQIndex, -1, -1, Gain, -1, True, Enable, nil);
end;

procedure TUosPlayer.Pause;
begin
  if uos_GetStatus(FPlayerIndex) = 1 then
  begin
    uos_Pause(FPlayerIndex);
    if Assigned(FOnPause) then
      FOnPause(Self);
  end;
end;

procedure TUosPlayer.Resume;
begin
  if uos_GetStatus(FPlayerIndex) = 2 then
  begin
    uos_RePlay(FPlayerIndex);
    if Assigned(FOnResume) then
      FOnResume(Self);
  end;
end;

procedure TUosPlayer.Stop;
begin
   if Assigned(FOnStop) then FOnStop(Self);
  uos_Stop(FPlayerIndex);
end;

function TUosPlayer.GetPlayerStatus: cint32;
begin
  Result := uos_GetStatus(FPlayerIndex);
end;

function TUosPlayer.GetTagTitle: string;
begin
 result:=uos_InputGetTagTitle(FPlayerIndex,FInputIndex);
end;

function TUosPlayer.GetTagArtist: string;
begin
  result:=uos_InputGetTagArtist(FPlayerIndex,FInputIndex);
end;

function TUosPlayer.GetTagAlbum: string;
begin
  result:=uos_InputGetTagAlbum(FPlayerIndex,FInputIndex);
end;

function TUosPlayer.GetTagDate: string;
begin
  result:=uos_InputGetTagDate(FPlayerIndex,FInputIndex);
end;

function TUosPlayer.GetTagComment: string;
begin
  result:=uos_InputGetTagComment(FPlayerIndex,FInputIndex);
end;

function TUosPlayer.GetIceCastTitle: string;
var Tegs:PChar;
begin
 if uos_InputUpdateICY(FPlayerIndex,FInputIndex,Tegs)<> -1 then
  result:=Tegs;

end;

function TUosPlayer.UpdateTag: boolean;
begin
  result:=uos_InputUpdateTag(FPlayerIndex,FInputIndex);
end;

end.
