program activity_tracker;

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  modules.listtaskwindows in 'modules.listtaskwindows.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
