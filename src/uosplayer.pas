unit UosPlayer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, uos_flat, ctypes;

type
  TSampleFormat = (sfFloat32, sfInt32, sfInt16);
  TLogPlayerEvent = procedure(Log: string) of object;
  TOnPlayningEvent = procedure(PositionLength: cint32; PositionTime: ttime) of object;
  { TUosPlayer }
  TUosPlayer = class(TComponent)
  private
    FLength: cint32;
    FLengthTime: ttime;
    FLibPath: string;
    FMusicFile: string;
    FOnLoadLib: TNotifyEvent;
    FOnLog: TLogPlayerEvent;
    FOnPause: TNotifyEvent;
    FOnPlay: TNotifyEvent;
    FOnPlayning: TOnPlayningEvent;
    FOnResume: TNotifyEvent;
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
    procedure SetMusicFile(AValue: string);
    procedure SetSampleFormat(AValue: TSampleFormat);
    procedure SetVolume_L(AValue: integer);
    procedure SetVolume_R(AValue: integer);
  protected
    procedure LoadUos;
    procedure LoopProcPlayer;
    procedure ClosePlayer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure InitPlayer;
    procedure Play;
    procedure Seek(Position: Tcount_t);
    procedure SeekSeconds(Position: cfloat);
    procedure SeekTime(Position: ttime);

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

  published
    property SampleFormat: TSampleFormat read FSampleFormat write SetSampleFormat;
    property MusicFile: string read FMusicFile write SetMusicFile;
    property LibPath: string read FLibPath write SetLibPath;
    property Volume_L: integer read FVolume_L write SetVolume_L;
    property Volume_R: integer read FVolume_R write SetVolume_R;
    property Length: cint32 read FLength;
    property LengthTime: ttime read FLengthTime;

    property OnLoadLib: TNotifyEvent read FOnLoadLib write FOnLoadLib;
    property OnPlay: TNotifyEvent read FOnPlay write FOnPlay;
    property OnPlayning: TOnPlayningEvent read FOnPlayning write FOnPlayning;
    property OnPause: TNotifyEvent read FOnPause write FOnPause;
    property OnResume: TNotifyEvent read FOnResume write FOnResume;
    property OnStop: TNotifyEvent read FOnStop write FOnStop;
    property OnTrackEnd:  TNotifyEvent read FOnTrackEnd write FOnTrackEnd;
    property OnLog: TLogPlayerEvent read FOnLog write FOnLog;

  end;

procedure Register;

implementation

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

procedure TUosPlayer.SetMusicFile(AValue: string);
begin
  if FMusicFile = AValue then
    Exit;
  FMusicFile := AValue;
end;

procedure TUosPlayer.SetSampleFormat(AValue: TSampleFormat);
begin
  if FSampleFormat = AValue then
    Exit;
  FSampleFormat := AValue;
end;

procedure TUosPlayer.SetVolume_L(AValue: integer);
begin
  if AValue <= 100 then
  begin
    FVolume_L := AValue;
    uos_InputSetDSPVolume(FPlayerIndex, FInputIndex, FVolume_L / 100,FVolume_R / 100, True);
  end
  else
    FVolume_R := 100;
end;

procedure TUosPlayer.SetVolume_R(AValue: integer);
begin
  if AValue <= 100 then
  begin
    FVolume_R := AValue;
    uos_InputSetDSPVolume(FPlayerIndex, FInputIndex, FVolume_L / 100, FVolume_R / 100, True);
  end
  else
    FVolume_R := 100;
end;

procedure TUosPlayer.LoadUos;
begin
  {$if defined(cpu64) and defined(linux) }
  FLibPortaudio := FLibPath + '/Linux/64bit/LibPortaudio-64.so';
  FLibSndFile := FLibPath + '/Linux/64bit/LibSndFile-64.so';
  FLibMpg123 := FLibPath + '/Linux/64bit/LibMpg123-64.so';
  FLibMp4ff := FLibPath + '/Linux/64bit/LibMp4ff-64.so';
  FLibFaad2 := FLibPath + '/Linux/64bit/LibFaad2-64.so';
  FLibOpusFile := FLibPath + '/Linux/64bit/LibOpusFile-64.so';
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

end;

procedure TUosPlayer.LoopProcPlayer;
begin
  if Assigned(FOnPlayning) then
  begin
    FOnPlayning(uos_InputPosition(FPlayerIndex, FInputIndex),
      uos_InputPositionTime(FPlayerIndex, FInputIndex));
  end;
end;

procedure TUosPlayer.ClosePlayer;
begin
  if Assigned(FOnTrackEnd) then FOnTrackEnd(Self);
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
begin
  if uos_GetStatus(FPlayerIndex) > 0 then
    Stop;

  case FSampleFormat of
    sfFloat32: samformat := 0;
    sfInt32: samformat := 1;
    sfInt16: samformat := 2;
  end;

  FInputIndex := -1;

  if FUosLoad and fileexists(FMusicFile) then
  begin
    FPlayerIndex := 0;
    if uos_CreatePlayer(FPlayerIndex) then
      FInputIndex := uos_AddFromFile(FPlayerIndex, PChar(FMusicFile), -1, samformat, -1);
    if FInputIndex > -1 then
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
      uos_InputSetDSPVolume(FPlayerIndex, FInputIndex, FVolume_L / 100,
        FVolume_R / 100, True); /// Set volume

      uos_Play(FPlayerIndex);

      FLength := uos_InputLength(FPlayerIndex, FInputIndex);
      FLengthTime := uos_InputLengthTime(FPlayerIndex, FInputIndex);

      if Assigned(FOnPlay) then
        FOnPlay(Self);
      if Assigned(FOnLog) then
        FOnLog('Playning ....');
    end
    else
    if Assigned(FOnLog) then
      FOnLog('Unable to open');

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
  uos_InputGetTagComment(FPlayerIndex,FInputIndex);
end;

end.
