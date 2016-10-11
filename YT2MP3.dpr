program YT2MP3;

uses
  Vcl.Forms,
  frmMain in 'frmMain.pas' {frmDownload};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmDownload, frmDownload);
  Application.Run;
end.
