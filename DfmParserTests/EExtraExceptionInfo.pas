unit EExtraExceptionInfo;

//
// You can add define's symbol name to the
// Project / Options / Delphi compiler / Conditional defines
// to enable a corresponding option. You can remove symbol name to disable option.
//

//==============================================================================

// Add additional exception's information as custom info to bug report
// {$DEFINE E_ADD_CUSTOM_INFO}

// Add additional exception's information to exception's message
// {$DEFINE E_ADD_CUSTOM_MESSAGE}

// Completely disable assist from this unit
// {$DEFINE E_ADD_NO_CUSTOM_INFO}

//------------------------------------------------------------------------------

//
// Select/add option(s) for exception classes which are used in your app:
//

// [System.Win.ComObj] EOleSysError, EOleException
// {$DEFINE E_SYSTEM_WIN_COM_INFO}

// DEPRECATED [Vcl.OleAuto] EOleSysError, EOleException (Delphi 6+)
// {$DEFINE E_VCL_OLEAUTO_INFO}

// [Data.DB] EUpdateError
// {$DEFINE E_DATA_DB_INFO}

// [System.Zip] EZipFileNotFoundException
// {$DEFINE E_SYSTEM_ZIP_INFO}

// [System.Net.Socket] ESocketError
// {$DEFINE E_SYSTEM_NET_SOCKET}

// [System.JSON] EJSONException
// {$DEFINE E_SYSTEM_JSON_INFO}

// [Xml.xmldom] DOMException, EDOMParseError
// {$DEFINE E_XML_INFO}

// [Xml.Internal.OmniXML] EXMLException [Xml.Internal.CodecUtilsWin32] EUnicodeCodecException
// {$DEFINE E_XML_OMNIXML}

// [Soap.InvokeRegistry] ERemotableException
// {$DEFINE E_SOAP_INVOKEREGISTRY_INFO}

// [REST.Types] ERequestError
// {$DEFINE E_REST_TYPES_INFO}

// [REST.HttpClient] EHTTPProtocolException
// {$DEFINE E_REST_HTTPCLIENT_INFO}

// [REST.Backend.EMSApi] EEMSClientHTTPError
// {$DEFINE E_REST_BACKEND_EMSAPI_INFO}

// [EMS.ResourceAPI] EEMSHTTPError
// {$DEFINE E_EMS_RESOURCEAPI_INFO}

// [Datasnap.Provider] EDSWriter
// {$DEFINE E_DATASNAP_PROVIDER_INFO}

// [Datasnap.DBClient] EDBClient, EReconcileError
// {$DEFINE E_DATASNAP_DBCLIENT_INFO}

// [Datasnap.DSClientRest] TDSRestProtocolException
// {$DEFINE E_DATASNAP_DSCLIENTREST_INFO}

// [Datasnap.DSHTTPClient] EHTTPProtocolException
// {$DEFINE E_DATASNAP_DSHTTPCLIENT_INFO}

// [Data.DBXCommon] TDBXError
// {$DEFINE E_DATA_DBXCOMMON_INFO}

// [Data.DBXStream] TDBXJSonError
// {$DEFINE E_DATA_DBXSTREAM_INFO}

// [Data.DbxHTTPLayer] EHTTPProtocolException
// {$DEFINE E_DATA_DBXHTTPLAYER_INFO}

interface

{$I ELDefines.inc}
{$IFDEF E_TEST_INFO}
  {$DEFINE E_SYSTEM_WIN_COM_INFO}
  {$DEFINE E_DATA_DB_INFO}
  {$DEFINE E_SYSTEM_ZIP_INFO}
  {$DEFINE E_SYSTEM_NET_SOCKET}
  {$DEFINE E_SYSTEM_JSON_INFO}
  {$DEFINE E_XML_INFO}
  {$DEFINE E_XML_OMNIXML}
  {$DEFINE E_SOAP_INVOKEREGISTRY_INFO}
  {$DEFINE E_REST_TYPES_INFO}
  {$DEFINE E_REST_HTTPCLIENT_INFO}
  {$DEFINE E_REST_BACKEND_EMSAPI_INFO}
  {$DEFINE E_EMS_RESOURCEAPI_INFO}
  {$DEFINE E_DATASNAP_PROVIDER_INFO}
  {$DEFINE E_DATASNAP_DBCLIENT_INFO}
  {$DEFINE E_DATASNAP_DSCLIENTREST_INFO}
  {$DEFINE E_DATASNAP_DSHTTPCLIENT_INFO}
  {$DEFINE E_DATA_DBXCOMMON_INFO}
  {$DEFINE E_DATA_DBXSTREAM_INFO}
  {$DEFINE E_DATA_DBXHTTPLAYER_INFO}
{$ENDIF}
{$IFNDEF E_ADD_CUSTOM_MESSAGE}
  {$DEFINE E_ADD_CUSTOM_INFO}
{$ENDIF}
{$IFDEF E_ADD_NO_CUSTOM_INFO}
  {$UNDEF E_ADD_CUSTOM_INFO}
  {$UNDEF E_ADD_CUSTOM_MESSAGE}
{$ENDIF}
{$IFNDEF COMPILER6_UP}
  {$UNDEF E_VCL_OLEAUTO_INFO}
  {$UNDEF E_XML_INFO}
  {$UNDEF E_SOAP_INVOKEREGISTRY_INFO}
{$ENDIF}
{$IFNDEF COMPILER11_UP} // 2007+
  {$UNDEF E_DATA_DBXCOMMON_INFO}
{$ENDIF}
{$IFNDEF COMPILER12_UP} // 2009+
  {$UNDEF E_DATA_DBXSTREAM_INFO}
{$ENDIF}
{$IFNDEF COMPILER16_UP} // XE2+
  {$UNDEF E_DATASNAP_PROVIDER_INFO}
  {$UNDEF E_DATASNAP_DBCLIENT_INFO}
  {$UNDEF E_DATASNAP_DSCLIENTREST_INFO}
{$ENDIF}
{$IFNDEF COMPILER19_UP} // XE5+
  {$UNDEF E_REST_HTTPCLIENT_INFO}
{$ENDIF}
{$IFNDEF COMPILER21_UP} // XE7+
  {$UNDEF E_REST_BACKEND_EMSAPI_INFO}
  {$UNDEF E_XML_OMNIXML}
{$ENDIF}
{$IFNDEF COMPILER23_UP} // 10+
  {$UNDEF E_DATASNAP_DSHTTPCLIENT_INFO}
{$ENDIF}
{$IFNDEF COMPILER24_UP} // 10.1+
  {$UNDEF E_REST_TYPES_INFO}
  {$UNDEF E_DATA_DBXHTTPLAYER_INFO}
{$ENDIF}
{$IFNDEF COMPILER26_UP} // 10.3+
  {$UNDEF E_SYSTEM_JSON_INFO}
{$ENDIF}
{$IFNDEF COMPILER28_UP} // 11+
  {$UNDEF E_SYSTEM_ZIP_INFO}
  {$UNDEF E_SYSTEM_NET_SOCKET}  
{$ENDIF}

implementation

{$IFNDEF E_ADD_NO_CUSTOM_INFO}
uses
  {$IFDEF COMPILER7_UP}
  {$IFDEF USE_NAMESPACES}System.VarUtils{$ELSE}VarUtils{$ENDIF},
  {$ENDIF}
  {$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF},
  {$IFDEF USE_NAMESPACES}System.Classes{$ELSE}Classes{$ENDIF},
  {$IFDEF E_SYSTEM_WIN_COM_INFO}
  {$IFDEF USE_NAMESPACES}System.Win.ComObj{$ELSE}ComObj{$ENDIF},
  {$ENDIF}
  {$IFDEF E_VCL_OLEAUTO_INFO}
  {$IFDEF USE_NAMESPACES}Vcl.OleAuto{$ELSE}OleAuto{$ENDIF},
  {$ENDIF}
  {$IFDEF E_DATA_DB_INFO}
  {$IFDEF USE_NAMESPACES}Data.DB{$ELSE}DB{$ENDIF},
  {$ENDIF}
  {$IFDEF E_SYSTEM_ZIP_INFO}
  System.Zip,
  {$ENDIF}
  {$IFDEF E_SYSTEM_NET_SOCKET}
  {$IFDEF USE_NAMESPACES}System.Net.Socket{$ELSE}Socket{$ENDIF},
  {$ENDIF}
  {$IFDEF E_SYSTEM_JSON_INFO}
  {$IFDEF USE_NAMESPACES}System.JSON{$ELSE}JSON{$ENDIF},
  {$ENDIF}
  {$IFDEF E_XML_INFO}
  {$IFDEF USE_NAMESPACES}Xml.xmldom{$ELSE}xmldom{$ENDIF},
  {$IFDEF E_XML_OMNIXML}
  Xml.Internal.OmniXML,
  Xml.Internal.CodecUtilsWin32,
  {$ENDIF}
  {$ENDIF}
  {$IFDEF E_SOAP_INVOKEREGISTRY_INFO}
  {$IFDEF USE_NAMESPACES}Soap.InvokeRegistry{$ELSE}InvokeRegistry{$ENDIF},
  {$ENDIF}
  {$IFDEF E_REST_TYPES_INFO}
  REST.Types,
  {$ENDIF}
  {$IFDEF E_REST_HTTPCLIENT_INFO}
  REST.HTTPClient,
  {$ENDIF}
  {$IFDEF E_REST_BACKEND_EMSAPI_INFO}
  REST.Backend.EMSAPI,
  {$ENDIF}
  {$IFDEF E_DATASNAP_PROVIDER_INFO}
  Datasnap.Provider,
  {$ENDIF}
  {$IFDEF E_DATASNAP_DBCLIENT_INFO}
  Datasnap.DBClient,
  {$ENDIF}
  {$IFDEF E_DATASNAP_DSCLIENTREST_INFO}
  Datasnap.DSClientREST,
  {$ENDIF}
  {$IFDEF E_DATASNAP_DSHTTPCLIENT_INFO}
  Datasnap.DSHTTPClient,
  {$ENDIF}
  {$IFDEF E_DATA_DBXCOMMON_INFO}
  {$IFDEF USE_NAMESPACES}Data.DBXCommon{$ELSE}DBXCommon{$ENDIF},
  {$ENDIF}
  {$IFDEF E_DATA_DBXSTREAM_INFO}
  {$IFDEF USE_NAMESPACES}Data.DBXStream{$ELSE}DBXStream{$ENDIF},
  {$ENDIF}
  {$IFDEF E_DATA_DBXHTTPLAYER_INFO}
  Data.DBXHTTPLayer,
  {$ENDIF}
  ETypes,
  EEvents,
  ECompatibility;

{$IFDEF E_DATA_DB_INFO}
resourcestring
  rsException = '[%s] %s';
{$ENDIF}

procedure DescribeException(const E: Exception; const AExceptionInfo: TEurekaExceptionInfo; Fields: TStrings);
var
  X: Integer;
begin
  if E is {$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF}.EInOutError then
  begin
    Fields.Values['EInOutError.ErrorCode'] := IntToStr({$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF}.EInOutError(E).ErrorCode);
    {$IFDEF COMPILER28_UP}
    { 11 Alexandria+ }
    Fields.Values['EInOutError.Path']      :=          {$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF}.EInOutError(E).Path;
    {$ENDIF}
  end;

  {$IFDEF COMPILER28_UP}
  { 11 Alexandria+ }
  if E is {$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF}.EInOutArgumentException then
    Fields.Values['EInOutArgumentException.Path'] := {$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF}.EInOutArgumentException(E).Path;
  {$ENDIF}  

  if (E is {$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF}.EExternal) and 
     (AExceptionInfo.ExceptionRecord.NumberParameters <= 15) then
  begin
    // EExternal(E).ExceptionRecord points to an invalid location on x64,
    // as the handle stage happens when the stack has been already released.
    // This does not happen on x32, which handles an exception while the stack is still occupied.
    Fields.Values['EExternal.ExceptionCode']    := '$' + IntToHex(        AExceptionInfo.ExceptionRecord.ExceptionCode, 8);
    Fields.Values['EExternal.ExceptionFlags']   :=       UIntToStr(       AExceptionInfo.ExceptionRecord.ExceptionFlags);
    Fields.Values['EExternal.ExceptionAddress'] := '$' + IntToHex(PtrUInt(AExceptionInfo.ExceptionRecord.ExceptionAddress), SizeOf(Pointer) * 2);
    Fields.Values['EExternal.NumberParameters'] :=       UIntToStr(       AExceptionInfo.ExceptionRecord.NumberParameters);
    if AExceptionInfo.ExceptionRecord.NumberParameters > 0 then
    begin
      for X := 0 to Integer(AExceptionInfo.ExceptionRecord.NumberParameters) - 1 do
        if AExceptionInfo.ExceptionRecord.ExceptionInformation[X] = 0 then
          Fields.Values[Format('EExternal.ExceptionInformation[%d]', [X])] := '0'
        else
        if (AExceptionInfo.ExceptionRecord.ExceptionInformation[X] > 0) and
           (AExceptionInfo.ExceptionRecord.ExceptionInformation[X] < 10) then
          Fields.Values[Format('EExternal.ExceptionInformation[%d]', [X])] := UIntToStr(AExceptionInfo.ExceptionRecord.ExceptionInformation[X])
        else
          Fields.Values[Format('EExternal.ExceptionInformation[%d]', [X])] := IntToHex(AExceptionInfo.ExceptionRecord.ExceptionInformation[X], SizeOf(AExceptionInfo.ExceptionRecord.ExceptionInformation[X]) * 2);
    end;
  end;

  if E is {$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF}.{$IFDEF COMPILER6_UP}EOSError{$ELSE}EWin32Error{$ENDIF} then
  begin
    if Integer({$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF}.{$IFDEF COMPILER6_UP}EOSError{$ELSE}EWin32Error{$ENDIF}(E).ErrorCode) < 0 then
      Fields.Values['EOSError.ErrorCode'] := '$' + IntToHex({$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF}.{$IFDEF COMPILER6_UP}EOSError{$ELSE}EWin32Error{$ENDIF}(E).ErrorCode, 8)
    else
      Fields.Values['EOSError.ErrorCode'] :=       IntToStr({$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF}.{$IFDEF COMPILER6_UP}EOSError{$ELSE}EWin32Error{$ENDIF}(E).ErrorCode);
  end;

  {$IFDEF COMPILER7_UP}
  if E is {$IFDEF USE_NAMESPACES}System.VarUtils{$ELSE}VarUtils{$ENDIF}.ESafeArrayError then
    Fields.Values['ESafeArrayError.ErrorCode'] := '$' + IntToHex({$IFDEF USE_NAMESPACES}System.VarUtils{$ELSE}VarUtils{$ENDIF}.ESafeArrayError(E).ErrorCode, 8);
  {$ENDIF}  

  {$IFDEF ANDROID}
  if E is {$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF}.EJNIException then
    Fields.Values['EJNIException.ExceptionClassName'] := {$IFDEF USE_NAMESPACES}System.SysUtils{$ELSE}SysUtils{$ENDIF}.EJNIException(E).ExceptionClassName;
  {$ENDIF}

  {$IFDEF E_SYSTEM_WIN_COM_INFO}
  if E is {$IFDEF USE_NAMESPACES}System.Win.ComObj{$ELSE}ComObj{$ENDIF}.EOleSysError then
  begin
    Fields.Values['EOleSysError.ErrorCode']   := '$' + IntToHex({$IFDEF USE_NAMESPACES}System.Win.ComObj{$ELSE}ComObj{$ENDIF}.EOleSysError(E).ErrorCode, 8);
    if E is {$IFDEF USE_NAMESPACES}System.Win.ComObj{$ELSE}ComObj{$ENDIF}.EOleException then
    begin
      Fields.Values['EOleException.Source']   := {$IFDEF USE_NAMESPACES}System.Win.ComObj{$ELSE}ComObj{$ENDIF}.EOleException(E).Source;
      Fields.Values['EOleException.HelpFile'] := {$IFDEF USE_NAMESPACES}System.Win.ComObj{$ELSE}ComObj{$ENDIF}.EOleException(E).HelpFile;
    end;
  end;
  {$ENDIF}

  {$IFDEF E_VCL_OLEAUTO_INFO}
  if E is {$IFDEF USE_NAMESPACES}Vcl.OleAuto{$ELSE}OleAuto{$ENDIF}.EOleSysError then
  begin
    Fields.Values['EOleSysError.ErrorCode']   := '$' + IntToHex({$IFDEF USE_NAMESPACES}Vcl.OleAuto{$ELSE}OleAuto{$ENDIF}.EOleSysError(E).ErrorCode, 8);
    if E is {$IFDEF USE_NAMESPACES}Vcl.OleAuto{$ELSE}OleAuto{$ENDIF}.EOleException then
    begin
      Fields.Values['EOleException.Source']   := {$IFDEF USE_NAMESPACES}Vcl.OleAuto{$ELSE}OleAuto{$ENDIF}.EOleException(E).Source;
      Fields.Values['EOleException.HelpFile'] := {$IFDEF USE_NAMESPACES}Vcl.OleAuto{$ELSE}OleAuto{$ENDIF}.EOleException(E).HelpFile;
    end;
  end;
  {$ENDIF}

  {$IFDEF E_DATA_DB_INFO}
  if E is {$IFDEF USE_NAMESPACES}Data.DB{$ELSE}DB{$ENDIF}.EUpdateError then
  begin
    Fields.Values['EUpdateError.Context']             :=          {$IFDEF USE_NAMESPACES}Data.DB{$ELSE}DB{$ENDIF}.EUpdateError(E).Context;
    Fields.Values['EUpdateError.ErrorCode']           := IntToStr({$IFDEF USE_NAMESPACES}Data.DB{$ELSE}DB{$ENDIF}.EUpdateError(E).ErrorCode);
    Fields.Values['EUpdateError.PreviousError']       := IntToStr({$IFDEF USE_NAMESPACES}Data.DB{$ELSE}DB{$ENDIF}.EUpdateError(E).PreviousError);
    if EUpdateError(E).OriginalException <> nil then
      Fields.Values['EUpdateError.OriginalException'] := Format(rsException, [{$IFDEF USE_NAMESPACES}Data.DB{$ELSE}DB{$ENDIF}.EUpdateError(E).OriginalException.ClassName, EUpdateError(E).OriginalException.Message]);
  end;
  {$ENDIF}

  {$IFDEF E_SYSTEM_NET_SOCKET}
  if E is {$IFDEF USE_NAMESPACES}System.Net.Socket{$ELSE}Socket{$ENDIF}.ESocketError then
    Fields.Values['ESocketError.Code'] := IntToStr({$IFDEF USE_NAMESPACES}System.Net.Socket{$ELSE}Socket{$ENDIF}.ESocketError(E).Code);
  {$ENDIF}

  {$IFDEF E_SYSTEM_ZIP_INFO}
  if E is System.Zip.EZipFileNotFoundException then
    Fields.Values['EZipFileNotFoundException.FileName'] := System.Zip.EZipFileNotFoundException(E).FileName;
  {$ENDIF}

  {$IFDEF E_SYSTEM_JSON_INFO}
  if E is System.JSON.EJSONParseException then
  begin
    Fields.Values['EJSONParseException.Path']     :=          System.JSON.EJSONParseException(E).Path;
    Fields.Values['EJSONParseException.Offset']   := IntToStr(System.JSON.EJSONParseException(E).Offset);
    Fields.Values['EJSONParseException.Line']     := IntToStr(System.JSON.EJSONParseException(E).Line);
    Fields.Values['EJSONParseException.Position'] := IntToStr(System.JSON.EJSONParseException(E).Position);
  end;
  {$ENDIF}

  {$IFDEF E_XML_INFO}
  if E is {$IFDEF USE_NAMESPACES}Xml.xmldom{$ELSE}xmldom{$ENDIF}.DOMException then
    Fields.Values['DOMException.code'] := IntToStr({$IFDEF USE_NAMESPACES}Xml.xmldom{$ELSE}xmldom{$ENDIF}.DOMException(E).code);
  if E is {$IFDEF USE_NAMESPACES}Xml.xmldom{$ELSE}xmldom{$ENDIF}.EDOMParseError then
  begin
    Fields.Values['EDOMParseError.ErrorCode'] := IntToStr({$IFDEF USE_NAMESPACES}Xml.xmldom{$ELSE}xmldom{$ENDIF}.EDOMParseError(E).ErrorCode);
    Fields.Values['EDOMParseError.URL']       :=          {$IFDEF USE_NAMESPACES}Xml.xmldom{$ELSE}xmldom{$ENDIF}.EDOMParseError(E).URL;
    Fields.Values['EDOMParseError.Reason']    :=          {$IFDEF USE_NAMESPACES}Xml.xmldom{$ELSE}xmldom{$ENDIF}.EDOMParseError(E).Reason;
    Fields.Values['EDOMParseError.SrcText']   :=          {$IFDEF USE_NAMESPACES}Xml.xmldom{$ELSE}xmldom{$ENDIF}.EDOMParseError(E).SrcText;
    Fields.Values['EDOMParseError.Line']      := IntToStr({$IFDEF USE_NAMESPACES}Xml.xmldom{$ELSE}xmldom{$ENDIF}.EDOMParseError(E).Line);
    Fields.Values['EDOMParseError.LinePos']   := IntToStr({$IFDEF USE_NAMESPACES}Xml.xmldom{$ELSE}xmldom{$ENDIF}.EDOMParseError(E).LinePos);
    Fields.Values['EDOMParseError.FilePos']   := IntToStr({$IFDEF USE_NAMESPACES}Xml.xmldom{$ELSE}xmldom{$ENDIF}.EDOMParseError(E).FilePos);
  end;
  {$ENDIF}

  {$IFDEF E_XML_OMNIXML}
  if E is Xml.Internal.OmniXML.EXMLException then
  begin
    Fields.Values['EXMLException.DOMCode'] := IntToStr(Xml.Internal.OmniXML.EXMLException(E).DOMCode);
    Fields.Values['EXMLException.XMLCode'] := IntToStr(Xml.Internal.OmniXML.EXMLException(E).XMLCode);
  end;
  if E is Xml.Internal.CodecUtilsWin32.EUnicodeCodecException then
    Fields.Values['EUnicodeCodecException.ProcessedBytes'] := IntToStr(Xml.Internal.CodecUtilsWin32.EUnicodeCodecException(E).ProcessedBytes);
  {$ENDIF}

  {$IFDEF E_SOAP_INVOKEREGISTRY_INFO}
  if E is {$IFDEF USE_NAMESPACES}Soap.InvokeRegistry{$ELSE}InvokeRegistry{$ENDIF}.ERemotableException then
  begin
    Fields.Values['ERemotableException.FaultActor']      := {$IFDEF USE_NAMESPACES}Soap.InvokeRegistry{$ELSE}InvokeRegistry{$ENDIF}.ERemotableException(E).FaultActor;
    Fields.Values['ERemotableException.FaultCode']       := {$IFDEF USE_NAMESPACES}Soap.InvokeRegistry{$ELSE}InvokeRegistry{$ENDIF}.ERemotableException(E).FaultCode;
    Fields.Values['ERemotableException.FaultDetail']     := {$IFDEF USE_NAMESPACES}Soap.InvokeRegistry{$ELSE}InvokeRegistry{$ENDIF}.ERemotableException(E).FaultDetail;
    {$IFDEF COMPILER14_UP}
    Fields.Values['ERemotableException.FaultReason']     := {$IFDEF USE_NAMESPACES}Soap.InvokeRegistry{$ELSE}InvokeRegistry{$ENDIF}.ERemotableException(E).FaultReason;
    Fields.Values['ERemotableException.FaultReasonLang'] := {$IFDEF USE_NAMESPACES}Soap.InvokeRegistry{$ELSE}InvokeRegistry{$ENDIF}.ERemotableException(E).FaultReasonLang;
    Fields.Values['ERemotableException.FaultNode']       := {$IFDEF USE_NAMESPACES}Soap.InvokeRegistry{$ELSE}InvokeRegistry{$ENDIF}.ERemotableException(E).FaultNode;
    Fields.Values['ERemotableException.FaultRole']       := {$IFDEF USE_NAMESPACES}Soap.InvokeRegistry{$ELSE}InvokeRegistry{$ENDIF}.ERemotableException(E).FaultRole;
    {$ENDIF}
  end;
  {$ENDIF}

  {$IFDEF E_REST_TYPES_INFO}
  if E is REST.Types.ERequestError then
  begin
    Fields.Values['ERequestError.StatusCode']      := IntToStr(REST.Types.ERequestError(E).StatusCode);
    Fields.Values['ERequestError.StatusText']      :=          REST.Types.ERequestError(E).StatusText;
    Fields.Values['ERequestError.ResponseContent'] :=          REST.Types.ERequestError(E).ResponseContent;
  end;
  {$ENDIF}

  {$IFDEF E_REST_HTTPCLIENT_INFO}
  if E is REST.HTTPClient.EHTTPProtocolException then
  begin
    Fields.Values['EHTTPProtocolException.ErrorCode']    := IntToStr(REST.HTTPClient.EHTTPProtocolException(E).ErrorCode);
    Fields.Values['EHTTPProtocolException.ErrorMessage'] :=          REST.HTTPClient.EHTTPProtocolException(E).ErrorMessage;
  end;
  {$ENDIF}

  {$IFDEF E_REST_BACKEND_EMSAPI_INFO}
  if E is REST.Backend.EMSAPI.EEMSClientHTTPError then
  begin
    Fields.Values['EEMSClientHTTPError.Code']        := IntToStr(REST.Backend.EMSAPI.EEMSClientHTTPError(E).Code);
    Fields.Values['EEMSClientHTTPError.Error']       :=          REST.Backend.EMSAPI.EEMSClientHTTPError(E).Error;
    Fields.Values['EEMSClientHTTPError.Description'] :=          REST.Backend.EMSAPI.EEMSClientHTTPError(E).Description;
  end;
  {$ENDIF}

  {$IFDEF E_DATASNAP_PROVIDER_INFO}
  if E is Datasnap.Provider.EDSWriter then
    Fields.Values['EDSWriter.ErrorCode'] := IntToStr(Datasnap.Provider.EDSWriter(E).ErrorCode);
  {$ENDIF}

  {$IFDEF E_DATASNAP_DBCLIENT_INFO}
  if E is Datasnap.DBClient.EDBClient then
    Fields.Values['EDBClient.ErrorCode'] := IntToStr(Datasnap.DBClient.EDBClient(E).ErrorCode);
  if E is Datasnap.DBClient.EReconcileError then
  begin
    Fields.Values['EReconcileError.PreviousError'] := IntToStr(Datasnap.DBClient.EReconcileError(E).PreviousError);
    Fields.Values['EReconcileError.Context']       :=          Datasnap.DBClient.EReconcileError(E).Context;
  end;
  {$ENDIF}

  {$IFDEF E_DATASNAP_DSCLIENTREST_INFO}
  if E is Datasnap.DSClientREST.TDSRestProtocolException then
  begin
    Fields.Values['TDSRestProtocolException.Status']       := IntToStr(Datasnap.DSClientREST.TDSRestProtocolException(E).Status);
    Fields.Values['TDSRestProtocolException.ResponseText'] :=          Datasnap.DSClientREST.TDSRestProtocolException(E).ResponseText;
  end;
  {$ENDIF}

  {$IFDEF E_DATASNAP_DSHTTPCLIENT_INFO}
  if E is Datasnap.DSHTTPClient.EHTTPProtocolException then
  begin
    Fields.Values['EHTTPProtocolException.ErrorCode']    := IntToStr(Datasnap.DSHTTPClient.EHTTPProtocolException(E).ErrorCode);
    Fields.Values['EHTTPProtocolException.ErrorMessage'] :=          Datasnap.DSHTTPClient.EHTTPProtocolException(E).ErrorMessage;
  end;
  {$ENDIF}

  {$IFDEF E_DATA_DBXCOMMON_INFO}
  if E is {$IFDEF USE_NAMESPACES}Data.DBXCommon{$ELSE}DBXCommon{$ENDIF}.TDBXError then
  begin
    Fields.Values['TDBXError.ErrorCode'] := {$IFDEF USE_NAMESPACES}Data.DBXCommon{$ELSE}DBXCommon{$ENDIF}.TDBXError.ErrorCodeToString({$IFDEF USE_NAMESPACES}Data.DBXCommon{$ELSE}DBXCommon{$ENDIF}.TDBXError(E).ErrorCode);
    Fields.Values['TDBXError.Message']   :=                                                                                           {$IFDEF USE_NAMESPACES}Data.DBXCommon{$ELSE}DBXCommon{$ENDIF}.TDBXError(E).Message;
  end;
  {$ENDIF}

  {$IFDEF E_DATA_DBXSTREAM_INFO}
  if E is {$IFDEF USE_NAMESPACES}Data.DBXStream{$ELSE}DBXStream{$ENDIF}.TDBXJsonError then
    Fields.Values['TDBXJsonError.JSonErrorCode'] := IntToStr({$IFDEF USE_NAMESPACES}Data.DBXStream{$ELSE}DBXStream{$ENDIF}.TDBXJsonError(E).JSonErrorCode);
  {$ENDIF}

  {$IFDEF E_DATA_DBXHTTPLAYER_INFO}
  if E is Data.DBXHTTPLayer.EHTTPProtocolException then
  begin
    Fields.Values['EHTTPProtocolException.ErrorCode']    := IntToStr(Data.DBXHTTPLayer.EHTTPProtocolException(E).ErrorCode);
    Fields.Values['EHTTPProtocolException.ErrorMessage'] :=          Data.DBXHTTPLayer.EHTTPProtocolException(E).ErrorMessage;
  end;
  {$ENDIF}
end;

{$IFDEF E_ADD_CUSTOM_INFO}
// Event handler for OnCustomDataRequest event
procedure DescribeExceptionInfo(const ACustom: Pointer;
  AExceptionInfo: TEurekaExceptionInfo;
  ALogBuilder: TObject;
  ADataFields: TStrings;
  var ACallNextHandler: Boolean);
begin
  if (not AExceptionInfo.ExceptionNative) or               // this is a Delphi exception
     (not Assigned(AExceptionInfo.ExceptionObject)) or     // Delphi's exception object is still alive
     (not (TObject(AExceptionInfo.ExceptionObject) is Exception)) then // exception must be Exception
    Exit;

  DescribeException(Exception(AExceptionInfo.ExceptionObject), AExceptionInfo, ADataFields);
end;
{$ENDIF}

{$IFDEF E_ADD_CUSTOM_MESSAGE}
// Event handler for OnExceptionNotify event
procedure DescribeExceptionMessage(const ACustom: Pointer;
  AExceptionInfo: TEurekaExceptionInfo;
  var AHandle: Boolean;
  var ACallNextHandler: Boolean);
var
  DataFields: TStringList;
  E: Exception;
  AdditionalInfo: String;
  X: Integer;
begin
  if (not AExceptionInfo.ExceptionNative) or               // this is a Delphi exception
     (not Assigned(AExceptionInfo.ExceptionObject)) or     // Delphi's exception object is still alive
     (not (TObject(AExceptionInfo.ExceptionObject) is Exception)) then // exception must be Exception
    Exit;

  DataFields := TStringList.Create;
  try
    E := Exception(AExceptionInfo.ExceptionObject);
    DescribeException(E, AExceptionInfo, DataFields);

    // Convert data fields into lines
    for X := 0 to DataFields.Count - 1 do
    begin
      AdditionalInfo := DataFields[X];
      if Pos('.', AdditionalInfo) < Pos('=', AdditionalInfo) then
      begin
        AdditionalInfo := Trim(Copy(AdditionalInfo, Pos('.', AdditionalInfo) + 1, MaxInt));
        DataFields[X] := AdditionalInfo;
      end;
    end;
    AdditionalInfo := Trim(DataFields.Text);

    if AdditionalInfo <> '' then
      AExceptionInfo.ExceptionMessage := AExceptionInfo.ExceptionMessage + sLineBreak + AdditionalInfo;

  finally
    FreeAndNil(DataFields);
  end;
end;
{$ENDIF}

initialization
  {$IFDEF E_ADD_CUSTOM_INFO}
  // Instruct EurekaLog to add custom fields to bug report
  RegisterEventCustomDataRequest(nil, DescribeExceptionInfo);
  {$ENDIF}
  {$IFDEF E_ADD_CUSTOM_MESSAGE}
  // Instruct EurekaLog to extend exception's message
  RegisterEventExceptionNotify(nil, DescribeExceptionMessage);
  {$ENDIF}
  
{$ENDIF E_ADD_NO_CUSTOM_INFO}
end.
