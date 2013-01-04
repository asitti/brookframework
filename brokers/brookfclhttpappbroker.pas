(*
  Brook FCL HTTPApp Broker unit.

  Copyright (C) 2013 Mario Ray Mahardhika.

  http://brookframework.org

  All contributors:
  Plase see the file CONTRIBUTORS.txt, included in this
  distribution.

  See the file LICENSE.txt, included in this distribution,
  for details about the copyright.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*)

unit BrookFCLHTTPAppBroker;

{$mode objfpc}{$H+}

interface

uses
  BrookClasses, BrookApplication, BrookException, BrookMessages, BrookConsts,
  BrookHTTPConsts, BrookRouter, BrookUtils, HTTPDefs, CustWeb, CustHTTPApp,
  FPJSON, Classes, SysUtils;

type
  TBrookHTTPApplication = class;

  { TBrookApplication }

  TBrookApplication = class(TBrookInterfacedObject, IBrookApplication)
  private
    FApp: TBrookHTTPApplication;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    function Instance: TObject;
    procedure Run;
  end;

  { TBrookHTTPApplication }

  TBrookHTTPApplication = class(TCustomHTTPApplication)
  protected
    function InitializeWebHandler: TWebHandler; override;
  end;

  { TBrookHTTPServerHandler }

  TBrookHTTPServerHandler = class(TFPHTTPServerHandler)
  protected
    function FormatContentType: string;
  public
    procedure HandleRequest(ARequest: TRequest; AResponse: TResponse); override;
    procedure ShowRequestException(R: TResponse; E: Exception); override;
  end;

implementation

{ TBrookApplication }

constructor TBrookApplication.Create;
begin
  FApp := TBrookHTTPApplication.Create(nil);
  FApp.Initialize;
end;

destructor TBrookApplication.Destroy;
begin
  FApp.Free;
  inherited Destroy;
end;

function TBrookApplication.Instance: TObject;
begin
  Result := FApp;
end;

procedure TBrookApplication.Run;
begin
  FApp.Run;
end;

{ TBrookHTTPApplication }

function TBrookHTTPApplication.InitializeWebHandler: TWebHandler;
begin
  Result := TBrookHTTPServerHandler.Create(Self);
end;

{ TBrookHTTPServerHandler }

function TBrookHTTPServerHandler.FormatContentType: string;
begin
  if BrookSettings.Charset <> ES then
    Result := BrookSettings.ContentType + BROOK_HTTP_HEADER_CHARSET +
      BrookSettings.Charset
  else
    Result := BrookSettings.ContentType;
end;

procedure TBrookHTTPServerHandler.HandleRequest(ARequest: TRequest;
  AResponse: TResponse);
begin
  try
    AResponse.ContentType := FormatContentType;
    if BrookSettings.Language <> BROOK_DEFAULT_LANGUAGE then
      TBrookMessages.Service.SetLanguage(BrookSettings.Language);
    TBrookRouter.Service.Route(ARequest, AResponse);
  except
    on E: Exception do
      ShowRequestException(AResponse, E);
  end;
end;

procedure TBrookHTTPServerHandler.ShowRequestException(R: TResponse; E: Exception);
var
  VStr: TStrings;
  VHandled: Boolean = False;
begin
  if R.ContentSent then
    Exit;
  if Assigned(BrookSettings.OnError) then
  begin
    BrookSettings.OnError(R, E, VHandled);
    if VHandled then
      Exit;
  end;
  if Assigned(OnShowRequestException) then
  begin
    OnShowRequestException(R, E, VHandled);
    if VHandled then
      Exit;
  end;
  if RedirectOnError and not R.HeadersSent then
  begin
    R.SendRedirect(Format(RedirectOnErrorURL, [HTTPEncode(E.Message)]));
    R.SendContent;
    Exit;
  end;
  if (BrookSettings.Page404 <> ES) and (E is EBrookHTTP404) and
    (not R.HeadersSent) then
  begin
    R.Code := BROOK_HTTP_STATUS_CODE_NOT_FOUND;
    R.CodeText := BROOK_HTTP_REASON_PHRASE_NOT_FOUND;
    R.ContentType := FormatContentType;
    if FileExists(BrookSettings.Page404) then
      R.Contents.LoadFromFile(BrookSettings.Page404)
    else
      R.Content := BrookSettings.Page404;
    R.Content := Format(R.Content, [ApplicationURL]);
  end;
  if (BrookSettings.Page500 <> ES) and (E is EBrookHTTP500) and
    (not R.HeadersSent) then
  begin
    R.Code := BROOK_HTTP_STATUS_CODE_INTERNAL_SERVER_ERROR;
    R.CodeText := 'Application error ' + E.ClassName;
    R.ContentType := FormatContentType;
    if FileExists(BrookSettings.Page500) then
    begin
      R.Contents.LoadFromFile(BrookSettings.Page500);
      R.Content := Format(R.Content, [E.Message]);
    end
    else
      if BrookSettings.ContentType = BROOK_HTTP_CONTENT_TYPE_APP_JSON then
        R.Content := Format(BrookSettings.Page500,
          [StringToJSONString(E.Message)])
      else
        R.Content := Format(BrookSettings.Page500, [E.Message]);
  end;
  if BrookSettings.ShowStackTraceOnError and
     ((R.ContentType = BROOK_HTTP_CONTENT_TYPE_TEXT_HTML) or
      (BrookSettings.ContentType = BROOK_HTTP_CONTENT_TYPE_TEXT_HTML)) then
  begin
    VStr := TStringList.Create;
    try
      R.ContentType := FormatContentType;
      ExceptionToHTML(VStr, E, Title, Email, Administrator);
      R.Content := R.Content + VStr.Text;
    finally
      VStr.Free;
    end;
  end;
  R.SendContent;
end;

initialization
  BrookRegisterApp(TBrookApplication.Create);

end.
