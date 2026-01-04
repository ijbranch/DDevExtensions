{******************************************************************************}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit SimpleXmlImport;

interface

uses
  SimpleXmlIntf, SimpleXmlDoc;

var
  LoadXmlDocument: function(const Filename: string): IXmlDocument
    = SimpleXmlDoc.LoadXmlDocument;
  NewXmlDocument: function(const Version: string = ''): IXmlDocument
    = SimpleXmlDoc.NewXmlDocument;

{function LoadXmlDocument(const Filename: string): IXmlDocument;
  external 'DDevExXml.dll';
function NewXmlDocument(const Version: string = ''): IXmlDocument;
  external 'DDevExXml.dll';}

implementation

end.
