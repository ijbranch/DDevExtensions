{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit DtmImages;

/// <summary>
/// Shared image-list data module used by every DDevExtensions feature for
/// menu glyphs, filter buttons, module-kind icons and application icons.
/// </summary>
/// <remarks>
/// The single global instance <see cref="DataModuleImages"/> is created in
/// <see cref="Main.InstallHooks"/> and freed in <see cref="Main.UninstallHooks"/>.
/// </remarks>

{$I DelphiExtension.inc}

interface

uses
  SysUtils, Classes, ImgList, Controls, Forms;

type
  /// <summary>Container for the four image lists shared across DDevExtensions UI.</summary>
  TDataModuleImages = class(TDataModule)
    /// <summary>General-purpose icons used for menus and tool windows.</summary>
    imlIcons: TImageList;
    /// <summary>Glyphs for filter combo boxes (column/directory filters).</summary>
    imlFilter: TImageList;
    /// <summary>Module-kind icons (Unit, Form, Frame, DataModule, Inherited Form, Binary).</summary>
    imlModules: TImageList;
    /// <summary>Application icons used in the project switcher and reload list.</summary>
    imlApplications: TImageList;
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
  end;

var
  /// <summary>Singleton instance of <see cref="TDataModuleImages"/>; lifetime managed by <c>Main</c>.</summary>
  DataModuleImages: TDataModuleImages;

const
  /// <summary>Index in <see cref="TDataModuleImages.imlModules"/> for a Pascal unit (.pas without form).</summary>
  imgModuleUnit = 0;
  /// <summary>Index for a form module.</summary>
  imgModuleForm = 1;
  /// <summary>Index for a frame module.</summary>
  imgModuleFrame = 2;
  /// <summary>Index for a data-module.</summary>
  imgModuleDataModule = 3;
  /// <summary>Index for a form that inherits from another form.</summary>
  imgModuleInheritForm = 4;
  /// <summary>Index for a binary resource module.</summary>
  imgModuleBinary = 5;

implementation

{$R *.dfm}

end.
