unit rhsIsValidURL;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils;

function IsValidURL(const sURL: String): Boolean;

implementation

function IsValidURL(const sURL: String): Boolean;
var
  i: Integer;
  PartList: TStringArray;
  sAdress: String = '';
  sProtocol: String = '';
  sForbidden: String = ' :?#[]@!$&()*+,;=.' + #39;
const
  ProtocolList: array[0..4] of string = ('https://www.', 'http://www.', 'https://', 'http://', 'www.');
begin
  Result := False;

  // sURL darf keine Leerzeichen enthalten oder mit einem reservierten Zeichen enden.
  if (Pos(' ', sURL) > 0) or (Pos(RightStr(sURL, 1), sForbidden) > 0) then
    Exit(False);

  // sURL muss mit einem der definierten Protokolle beginnen.
  for i := 0 to 4 do
  begin
    if Pos(ProtocolList[i], Lowercase(sURL)) = 1 then
    begin
      sProtocol := ProtocolList[i];
      Break;
    end;
  end;
  if sProtocol.IsEmpty then
    Exit(False);

  // Die Adresse darf incl. Protokoll maximal 255 Zeichen lang sein.
  sAdress := sURL.Substring(sProtocol.Length, 255 - sProtocol.Length);

  // Nur die Zeichen vor dem ersten Pfadtrenner gehören zur Adresse.
  i := sAdress.IndexOf('/');
  if i > -1 then
    sAdress := LeftStr(sAdress, i);

  // Adresse in Subdomain(s), Second-Level-Domain und Top-Level-Domain aufteilen.
  PartList := sAdress.Split('.');

  // Die Adresse muss aus mindestens zwei Teilen bestehen (Second-Level-Domain und Top-Level-Domain).
  if High(PartList) < 1 then
    Exit(False);

  // Die Adressteile dürfen nicht leer sein oder reservierte Zeichen enthalten.
  for i := 0 to High(PartList) do
    if (PartList[i].IsEmpty) or (PosSet(sForbidden, PartList[i]) > 0) then
      Exit(False);

  Result := True;
end;
end.
