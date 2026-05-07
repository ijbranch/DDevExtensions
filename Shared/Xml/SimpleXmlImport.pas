{******************************************************************************}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit SimpleXmlImport;

/// <summary>
/// Indirection layer that lets callers swap the LoadXmlDocument / NewXmlDocument factory
/// functions at run time. By default the variables point to SimpleXmlDoc but applications can
/// reassign them to load XML through an alternative implementation (such as a separate DLL).
/// </summary>

interface

uses
  SimpleXmlIntf, SimpleXmlDoc;

var
  /// <summary>Function pointer that loads an IXmlDocument from a file. Defaults to SimpleXmlDoc.LoadXmlDocument.</summary>
  LoadXmlDocument: function(const Filename: string): IXmlDocument
    = SimpleXmlDoc.LoadXmlDocument;
  /// <summary>Function pointer that creates a new empty IXmlDocument. Defaults to SimpleXmlDoc.NewXmlDocument.</summary>
  NewXmlDocument: function(const Version: string = ''): IXmlDocument
    = SimpleXmlDoc.NewXmlDocument;

{function LoadXmlDocument(const Filename: string): IXmlDocument;
  external 'DDevExXml.dll';
function NewXmlDocument(const Version: string = ''): IXmlDocument;
  external 'DDevExXml.dll';}

implementation

end.
