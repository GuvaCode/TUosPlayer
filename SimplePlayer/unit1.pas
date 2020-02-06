unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  UosPlayer, ctypes;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Edit1: TEdit;
    LogBox: TListBox;
    OpenDialog1: TOpenDialog;
    Player: TUosPlayer;
    ProgressBar1: TProgressBar;
    ProgressBar11: TProgressBar;
    ProgressBar12: TProgressBar;
    ProgressBar2: TProgressBar;
    ProgressBar3: TProgressBar;
    ProgressBar4: TProgressBar;
    ProgressBar5: TProgressBar;
    ProgressBar6: TProgressBar;
    ProgressBar7: TProgressBar;
    ProgressBar8: TProgressBar;
    TrackBar1: TTrackBar;
    VolBar: TTrackBar;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure PlayerBandLevel(BabdArray: array of cfloat);
    procedure PlayerLog(Log: string);
    procedure PlayerPlay(Sender: TObject);
    procedure PlayerPlayning(PositionLength: cint32; PositionTime: ttime);
    procedure PlayerShowLevel(LeftLevel, RightLevel: Double);
    procedure TrackBar1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure TrackBar1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure VolBarChange(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;
  x:integer;
implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormShow(Sender: TObject);
begin
 Player.LibPath:='libs/Linux/64bit/';
 Player.InitPlayer;
 VolBar.Position:=Player.Volume_L;
end;

procedure TForm1.PlayerBandLevel(BabdArray: array of cfloat);
var i,v:integer;
begin
    i:=1;
    x := 0;
    while x < length(BabdArray) -1 do
    begin
      if i<=8 then
      begin
        v:= trunc((BabdArray[x]+BabdArray[x+1])*50);
        TProgressBar(findcomponent('ProgressBar'+inttostr(i))).position:=v;
      end;
      x:=x+2;
      inc(i);
    end;

end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  if opendialog1.Execute then Player.FileName:=OpenDialog1.FileName;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
 if edit1.Text<>'' then Player.FileName:=Edit1.Text;
  Player.Play;
  LogBox.Items.Add(Player.GetTagTitle);
  LogBox.Items.Add(Player.GetTagArtist);
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  LogBox.Items.Add(Player.GetIceCastTitle);
end;

procedure TForm1.PlayerLog(Log: string);
begin
  LogBox.Items.Add(Log);
end;

procedure TForm1.PlayerPlay(Sender: TObject);
begin
 TrackBar1.Max:=Player.Length;
end;

procedure TForm1.PlayerPlayning(PositionLength: cint32; PositionTime: ttime);
var
  temptime: ttime;
  ho, mi, se, ms: word;
begin
 if TrackBar1.Tag = 0 then
 begin
 TrackBar1.Position:=PositionLength;
 temptime := PositionTime;
 DecodeTime(temptime, ho, mi, se, ms);
 Caption := format('%.2d:%.2d:%.2d.%.3d', [ho, mi, se, ms]);
 end;

end;

procedure TForm1.PlayerShowLevel(LeftLevel, RightLevel: Double);
begin
   ProgressBar12.Position:=Round(RightLevel*99);
   ProgressBar11.Position:=Round(LeftLevel*99);
end;

procedure TForm1.TrackBar1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
 TrackBar1.Tag := 1;
end;

procedure TForm1.TrackBar1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  Player.Seek(TrackBar1.Position);
  TrackBar1.Tag := 0;
end;

procedure TForm1.VolBarChange(Sender: TObject);
begin
  Player.Volume_L:=VolBar.Position;
  Player.Volume_R:=Player.Volume_L;
end;

end.

