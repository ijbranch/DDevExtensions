{$A+,B-,C+,D+,E-,F-,G+,H+,I+,J-,K-,L+,M-,N+,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}

{------------------------------------------------------------------------------}
{ Compiler version defines for Delphi 10.2 Tokyo and higher                    }
{ Replaces jedi.inc - all these are always TRUE for Delphi 10.2+               }
{------------------------------------------------------------------------------}

{$DEFINE COMPILER6_UP}
{$DEFINE COMPILER7_UP}
{$DEFINE COMPILER9_UP}
{$DEFINE COMPILER10_UP}
{$DEFINE COMPILER11_UP}
{$DEFINE COMPILER12_UP}
{$DEFINE DELPHI2007_UP}
{$DEFINE IDE50}
{$DEFINE IDE50_UP}

{$IF CompilerVersion >= 35}
  { Delphi 11 Alexandria and higher }
  {$DEFINE COMPILER110_UP}
  {$DEFINE DELPHI28_UP}
{$IFEND}

{$DEFINE DDEVEXTENSIONS}

{$IFDEF COMPILER7_UP}
{$WARN UNSAFE_TYPE OFF}
{$WARN UNSAFE_CODE OFF}
{$WARN UNSAFE_CAST OFF}
{$ENDIF}


{$IFDEF RELEASE}
{$D-}
{$ENDIF}

{------------------------------------------------------------------------------}
{$DEFINE INCLUDE_PROJECTSETTINGS}
{$DEFINE INCLUDE_COMPILEPROGRESS}
{$DEFINE INCLUDE_IDEMENUHANDLER} // BDS IDE bugfix: Alt+F12 key bugfix
{$DEFINE INCLUDE_UNITSELECTOR}
{$DEFINE INCLUDE_KEYBINDINGS}
{$DEFINE INCLUDE_FILECLEANER}
{$DEFINE INCLUDE_COMPILEBACKUP}
{$DEFINE INCLUDE_FOCUSEDITOR}
{$DEFINE INCLUDE_FORMDESIGNER} // 1.4
{$DEFINE INCLUDE_STARTPARAMETERTEAM} // 1.5
{$DEFINE INCLUDE_FILESELECTOR} // 1.5
{$DEFINE INCLUDE_STRUCVIEWSEARCH} // 2.0
{$DEFINE INCLUDE_COMPONENTSELECTOR}
{$DEFINE INCLUDE_OLDPALETTE}
{$DEFINE INCLUDE_DEPENDENCYVIEWER}
{$DEFINE INCLUDE_UNUSEDUNITDETECTOR}
{$DEFINE INCLUDE_TODOAGGREGATOR}
{$DEFINE INCLUDE_CODESTYLECHECKER}
{$DEFINE INCLUDE_DEADCODEDETECTOR}
{$DEFINE INCLUDE_UNREACHABLECODEDETECTOR}
{$DEFINE INCLUDE_USESCLAUSEMANAGER}
{$DEFINE INCLUDE_EMPTYEVENTHANDLERDETECTOR}
{$DEFINE INCLUDE_DFMPASCONSISTENCY}

{------------------------------------------------------------------------------}
// dependencies

{$IFDEF INCLUDE_COMPONENTSELECTOR}
 {$DEFINE NEED_COMPONENTMANAGER}
{$ENDIF}

{$IFDEF INCLUDE_OLDPALETTE}
 {$DEFINE NEED_COMPONENTMANAGER}
{$ENDIF}

{------------------------------------------------------------------------------}
// version limitations

{$DEFINE ALWAYS_DEFINED}

{$IF CompilerVersion > 23.0} // XE2+
  {$UNDEF INCLUDE_STARTPARAMETERTEAM} // XE2's StartParameter are configuration-aware
{$IFEND}

{------------------------------------------------------------------------------}

