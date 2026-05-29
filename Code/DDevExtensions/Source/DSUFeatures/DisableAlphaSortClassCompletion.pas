{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit DisableAlphaSortClassCompletion;

/// <summary>
/// Installs binary patches into the Delphi class-completion code so that newly generated
/// method stubs are inserted in declaration order rather than alphabetically. Locates the
/// relevant call sites by signature scanning and redirects TSortedThingList.SetSorted and
/// TTableIterator construction/iteration through replacement routines defined in this unit.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

/// <summary>
/// Installs (when Value is True) or removes the alpha-sort-disable patches in the IDE's
/// class completer.
/// </summary>
/// <param name="Value">True to disable alphabetical sorting; False to restore the original IDE behaviour.</param>
procedure InstallDisableAlphaSortClassCompletion(Value: Boolean);

implementation

{$IFDEF CPUX86}

uses
  Windows, SysUtils, Classes, TypInfo, Hooking, IDEHooks;

type
  /// <summary>
  /// Opaque placeholder mirroring the IDE's internal TClassSymbol used to type
  /// the patched MethodAddPos call.
  /// </summary>
  TClassSymbol = class
  end;

  /// <summary>
  /// Layout-compatible mirror of the IDE's symbol-table base record. Field order and
  /// types must match the compiler's internal representation exactly.
  /// </summary>
  TBaseSymbol = class(TObject)
  public
    /// <summary>Next symbol in the hash bucket chain.</summary>
    Next: TBaseSymbol;
    /// <summary>UTF-8 encoded short-form identifier.</summary>
    FShortIdent: ShortString;    //UTF8-encoded data
    /// <summary>Unicode form of the identifier.</summary>
    FIdent: UnicodeString;
  end;

  /// <summary>
  /// Layout-compatible mirror of the IDE's symbol table. Only Count and the bucket array
  /// are accessed.
  /// </summary>
  TSymbolTable = class(TObject)
  private
    /// <summary>Total number of symbols stored.</summary>
    FCount: Integer;
    /// <summary>Hash buckets holding linked lists of symbols.</summary>
    FSymbolList: array[0..31] of TBaseSymbol;
    //FCompare: TCompareSymbols;
  public
    /// <summary>Returns the number of symbols in the table.</summary>
    property Count: Integer read FCount;
  end;

  /// <summary>
  /// Replacement iterator that loads all symbols from a TSymbolTable and sorts them in
  /// declaration order rather than the IDE's default alphabetical order.
  /// </summary>
  TTableIterator = class
  protected
    /// <summary>Layout filler matching IDE iterator field offsets.</summary>
    FxxxLocation: Integer;
    /// <summary>Layout filler matching IDE iterator field offsets.</summary>
    FxxxIndex: Integer;
    /// <summary>Layout filler matching IDE iterator field offsets.</summary>
    FxxxSymbol: TBaseSymbol;
    /// <summary>Number of symbols loaded; field offset must match the IDE's iterator.</summary>
    FCount: Integer; // FCount must be at this offset

    /// <summary>Sorted snapshot of the symbols copied from the source table.</summary>
    FSymbols: array of TBaseSymbol;

    /// <summary>Returns the symbol at the given zero-based index.</summary>
    /// <param name="Index">Zero-based symbol index.</param>
    /// <returns>The symbol stored at Index in FSymbols.</returns>
    function GetSymbol(Index: Integer): TBaseSymbol;
    /// <summary>Copies all symbols from Table into FSymbols and sorts them.</summary>
    /// <param name="Table">Source symbol table to enumerate.</param>
    procedure LoadSymbols(Table: TSymbolTable);
    /// <summary>Recursive in-place quick-sort over FSymbols using CompareSymbol.</summary>
    /// <param name="L">Lower bound (inclusive).</param>
    /// <param name="R">Upper bound (inclusive).</param>
    procedure QuickSort(L, R: Integer);
  public
    /// <summary>Creates the iterator and populates it from the supplied table.</summary>
    /// <param name="Table">Symbol table to snapshot, or nil for an empty iterator.</param>
    constructor Create(Table: TSymbolTable);
    /// <summary>Number of symbols held by the iterator.</summary>
    property Count: Integer read FCount;
    /// <summary>Indexed access to the loaded symbols.</summary>
    property Symbols[Index: Integer]: TBaseSymbol read GetSymbol; default;
  end;

  TMethodSymbol = class;

  /// <summary>
  /// Mirrors the IDE's access-specifier enumeration for class members.
  /// </summary>
  TAccess = (saDefault, saStrictPrivate, saPrivate, saStrictProtected, saProtected, saPublic, saPublished, saAutomated);

  /// <summary>
  /// Layout-compatible mirror of the IDE's method-signature record. Only the fields
  /// referenced by sort/order logic are documented; the rest are positional placeholders.
  /// </summary>
  TMethodSignature = class
  public
    /// <summary>Owning method symbol.</summary>
    MethodSymbol: TMethodSymbol;
    /// <summary>RTTI describing the method type.</summary>
    TypeData: PTypeData;
    /// <summary>Size in bytes of the typed parameter block.</summary>
    TypeSize: Word;
    /// <summary>True when the method has no parameters or body.</summary>
    Empty: Boolean;
    /// <summary>Source positions of the interface declaration header.</summary>
    HeaderPos, HeaderNamePos, HeaderEnd, HeaderLineEnd: LongInt;
    /// <summary>Source positions of the implementation header and body.</summary>
    CodePos, CodeNamePos, CodeHeaderEnd, CodeBegin, CodeEnd, CodeStatement: LongInt;
    /// <summary>Source positions for implementation header end markers.</summary>
    ImplHeaderEnd, ImplEnd: LongInt;
    /// <summary>Source position of the begin keyword.</summary>
    BeginPos: LongInt;
    /// <summary>Visibility of the method declaration.</summary>
    Access: TAccess;
    /// <summary>Source range of the optional dispid clause.</summary>
    DispidPos, DispidEnd: LongInt;
    /// <summary>Next signature in a chained list (e.g. overloaded methods).</summary>
    Next: TMethodSignature;
    /// <summary>True if this method is part of an interface declaration.</summary>
    InterfaceMethod: Boolean;
    /// <summary>Symbol table of locally-declared nested procedures.</summary>
    NestedProcedures: TSymbolTable;

    /// <summary>Returns True when the method has a body in the implementation section.</summary>
    /// <returns>True if CodePos and TypeData are both set.</returns>
    function IsImplemented: Boolean;
    /// <summary>Returns a sort weight grouping constructors, destructors and operators ahead of normal methods.</summary>
    /// <returns>An integer used to keep declaration order stable across kinds.</returns>
    function GetTypeSortId: Integer;
  end;

  /// <summary>
  /// Mirrors the IDE's method-symbol class, exposing the signature pointer used by sorting.
  /// </summary>
  TMethodSymbol = class(TBaseSymbol)
  public
    /// <summary>Backing signature describing this method.</summary>
    FMethodSignature: TMethodSignature;
  end;

var
  OrgTClassSymbol_MethodAddPos: function(Instance: TClassSymbol; const Name: string): Integer;
  OrgTSortedThingList_SetSorted: Pointer;
  OrgTTableIterator_Ctor: Pointer;
  OrgTTableIterator_GetSymbol: Pointer;

  CallAddrTSortedThingList_SetSortedP: PByte;
  CompleteMethodSymbolTableIteratorP: PByte;

function TClassSymbol_MethodAddPos(Instance: TClassSymbol; const Name: string): Integer;
  external delphicoreide_bpl name '@Pasmgr@TClassSymbol@MethodAddPos$qqrx20System@UnicodeString';

procedure TPascalClassCompleter_Complete;
  external delphicoreide_bpl name '@Completers@TPascalClassCompleter@Complete$qqrx20System@UnicodeString';

function TClassSymbol_MethodAddPos_AlphSort(Instance: TClassSymbol; const Name: string): Integer;
begin
  Result := OrgTClassSymbol_MethodAddPos(Instance, '');
end;

procedure TSortedThingList_SetSorted(Instance: TObject; Value: Boolean);
begin
  // don't sort the list, the TTableIterator already did that
end;

{ TTableIterator }

constructor TTableIterator.Create(Table: TSymbolTable);
begin
  inherited Create;
  if Table <> nil then
    LoadSymbols(Table);
end;

procedure TTableIterator.LoadSymbols(Table: TSymbolTable);
var
  Index: Integer;
  Symbol: TBaseSymbol;
  Location: Integer;
begin
  FCount := Table.Count;
  SetLength(FSymbols, FCount);

  Index := 0;
  for Location := 0 to Length(Table.FSymbolList) - 1 do
  begin
    Symbol := Table.FSymbolList[Location];
    if Symbol <> nil then
    begin
      repeat
        FSymbols[Index] := Symbol;
        Inc(Index);
        Symbol := Symbol.Next;
      until Symbol = nil;
      if Index >= FCount then
        Break;
    end;
  end;

  if Count > 0 then
    QuickSort(0, Count - 1);
end;

function TTableIterator.GetSymbol(Index: Integer): TBaseSymbol;
begin
  Result := FSymbols[Index];
end;


function CompareInt(V1, V2: Integer): Integer; inline;
begin
  if V1 = V2 then
    Result := 0
  else if V1 > V2 then
    Result := 1
  else
    Result := -1;
end;

function CompareSymbol(Sym1, Sym2: TBaseSymbol): Integer;
var
  M1, M2: TMethodSymbol;
  Id1, Id2: Integer;
  HP1, HP2: Integer;
begin
  if Sym1 <> Sym2 then
  begin
    M1 := TMethodSymbol(Sym1);
    M2 := TMethodSymbol(Sym2);
    Id1 := M1.FMethodSignature.GetTypeSortId;
    Id2 := M2.FMethodSignature.GetTypeSortId;

    if Id1 = Id2 then
    begin
      HP1 := M1.FMethodSignature.HeaderPos;
      HP2 := M2.FMethodSignature.HeaderPos;
      if (HP1 = 0) and (HP2 = 0) then
        Result := CompareInt(M1.FMethodSignature.CodePos, M2.FMethodSignature.CodePos)
      else
        Result := CompareInt(HP1, HP2);
    end
    else if Id1 > Id2 then
      Result := 1
    else
      Result := -1;
  end
  else
    Result := 0;
end;

procedure TTableIterator.QuickSort(L, R: Integer);
var
  I, J: Integer;
  P, T: TBaseSymbol;
begin
  repeat
    I := L;
    J := R;
    P := FSymbols[(L + R) shr 1];
    repeat
      while CompareSymbol(FSymbols[I], P) < 0 do
        Inc(I);
      while CompareSymbol(FSymbols[J], P) > 0 do
        Dec(J);
      if I <= J then
      begin
        if I <> J then
        begin
          T := FSymbols[I];
          FSymbols[I] := FSymbols[J];
          FSymbols[J] := T;
        end;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then
      QuickSort(L, J);
    L := I;
  until I >= R;
end;

{ TMethodSignature }

function TMethodSignature.IsImplemented: Boolean;
begin
  Result := (CodePos <> 0) and (TypeData <> nil);
end;

function TMethodSignature.GetTypeSortId: Integer;
begin
  Result := 100;
  if TypeData <> nil then
  begin
    case TypeData.MethodKind of
      mkClassConstructor:
        Result := 0;
      {$IF CompilerVersion >= 21.0} // 2010+
      mkClassDestructor:
        Result := 1;
      {$IFEND}
      mkConstructor:
        Result := 2;
      mkDestructor:
        Result := 3;
//      mkClassProcedure, mkClassFunction:
//        Result := 4;
      mkOperatorOverload:
        Result := 200;
    end;
  end;
end;

{-------------------------------------------------------------------------------------------------}

function TTableIterator_Create(ASymbolTable: TSymbolTable): TTableIterator;
begin
  Result := TTableIterator.Create(ASymbolTable);
end;

function MethodSymbolTableIteratorFactory(AClass: TClass; DL: Integer; ASymbolTable: TSymbolTable): TTableIterator;
asm
  push ecx

  // Sort all items that are already collected
  mov eax, [ebp-$10] // Thingslist
  mov edx, 1
  call [OrgTSortedThingList_SetSorted]

  // Disable sorting so that the methods can be added in their correct order
// !!! Sorting is implemented wrongly. Disabling sort calls TList.Sort, and as long as nobody calls SetSorted no further sorting is done
//  mov eax, [ebp-$10] // Thingslist
//  xor edx, edx
//  call [OrgTSortedThingList_SetSorted]

  pop eax
  call TTableIterator_Create
end;
{begin
  // Sort all items that are already collected
  OrgTSortedThingList_SetSorted(ThingList, True);
  // Disable sorting so that the methods can be added in their correct order
  //OrgTSortedThingList_SetSorted(ThingList, False);

  Result := TTableIterator.Create;
end;}

{-------------------------------------------------------------------------------------------------}

procedure InstallDisableAlphaSortClassCompletion(Value: Boolean);
const
  CompleteSetSortedBytes: array[0..18] of SmallInt = (
    $B2, $01,             // mov dl,$01                                    //  0
    $8B, $45, $F0,        // mov eax,[ebp-$10]                             //  2  == SortedThingList (used in CompleteMethodSymbolTableIteratorBytes)
    $E8, -1, -1, -1, -1,  // call TSortedThingList.SetSorted  ; $21ce165c  //  5
    $8B, $45, $F0,        // mov eax,[ebp-$10]                             // 10
    {$IF CompilerVersion >= 25.0} // XE4+
    $8B, $78, $08,        // mov edi,[eax+$08]                             // 13
    $4F,                  // dec edi                                       // 16
    $85, $FF              // test edi,edi                                  // 17
    {$ELSE}
    $8B, $70, $08,        // mov esi,[eax+$08]                             // 13
    $4E,                  // dec esi                                       // 16
    $85, $F6              // test esi,esi                                  // 17
    {$IFEND}
  );
  CallOffsetSetSorted = 5;

  CompleteMethodSymbolTableIteratorBytes: array[0..71] of SmallInt = (
    $8B, $45, $F8,                      // mov eax,[ebp-$08]                           //  0
    $8B, $88, -1, -1, $00, $00,         // mov ecx,[eax+$0000012c]                     //  3
    $B2, $01,                           // mov dl,$01                                  //  9
    $A1, -1, -1, -1, -1,                // mov eax,[$21df1e68]                         // 11
    $E8, -1, -1, -1, -1,                // call TTableIterator.Create  ; $21c646c4     // 16 // => call MethodSymbolTableIteratorFactory
    {$IF CompilerVersion = 21.0} // 2010 what did they do?
    $89, $45, $C0,                      // mov [ebp-$40],eax                           // 21
    {$ELSE}
    $89, $45, $C4,                      // mov [ebp-$3c],eax                           // 21
    {$IFEND}
    $33, $C0,                           // xor eax,eax                                 // 24
    $55,                                // push ebp                                    // 26
    $68, -1, -1, -1, -1,                // push $21ce114d                              // 27
    $64, $FF, $30,                      // push dword ptr fs:[eax]                     // 32
    $64, $89, $20,                      // mov fs:[eax],esp                            // 35
    {$IF CompilerVersion = 21.0} // 2010 what did they do?
    $8B, $45, $C0,                      // mov eax,[ebp-$40]                           // 38
    {$ELSE}
    $8B, $45, $C4,                      // mov eax,[ebp-$3c]                           // 38
    {$IFEND}
    $8B, -1, $10,                       // mov edi,[eax+$10]                           // 41
    -1,                                 // dec edi                                     // 44
    $85, -1,                            // test edi,edi                                // 45
    $0F, $8C, -1, -1, $00, $00,         // jl $21ce1137                                // 47
    -1,                                 // inc edi                                     // 53
    {$IF CompilerVersion = 21.0} // 2010 what did they do?
    $C7, $45, $CC, $00, $00, $00, $00,  // mov [ebp-$34],$00000000                     // 54
    $8B, $55, $CC,                      // mov edx,[ebp-$30]                           // 61
    $8B, $45, $C0,                      // mov eax,[ebp-$40]                           // 64
    {$ELSE}
    $C7, $45, $D0, $00, $00, $00, $00,  // mov [ebp-$30],$00000000                     // 54
    $8B, $55, $D0,                      // mov edx,[ebp-$34]                           // 61
    $8B, $45, $C4,                      // mov eax,[ebp-$3c]                           // 64
    {$IFEND}
    $E8, -1, -1, -1, -1                 // call TTableIterator.GetSymbol  ; $21c646cc  // 67  => replace with out GetSymbol method
  );
  CallOffsetTabCtor = 16;
  CallOffsetGetSymbol = 67;

begin
  if Value then
  begin
    if CallAddrTSortedThingList_SetSortedP = nil then
    begin
      CompleteMethodSymbolTableIteratorP := FindMethodPtr(GetActualAddr(@TPascalClassCompleter_Complete), CompleteMethodSymbolTableIteratorBytes, $10000);
      CallAddrTSortedThingList_SetSortedP := FindMethodPtr(CompleteMethodSymbolTableIteratorP, CompleteSetSortedBytes, $1000);

      // Code-Search: Breakpoint in TClassSymbol_MethodAddPos_AlphSort, start, add method to class decl., press Ctrl+Shift+C, debug through function returns until you are in method "Complete"
      if (CallAddrTSortedThingList_SetSortedP = nil) and (DebugHook <> 0) then
        MessageBox(0, 'InstallDisableAlphaSortClassCompletion byte sequences not found', 'DDevExtensions', MB_OK or MB_ICONWARNING);

      if (CompleteMethodSymbolTableIteratorP <> nil) and (CallAddrTSortedThingList_SetSortedP <> nil) then
      begin
        OrgTTableIterator_Ctor := GetCallTargetAddress(@CompleteMethodSymbolTableIteratorP[CallOffsetTabCtor]);
        OrgTTableIterator_GetSymbol := GetCallTargetAddress(@CompleteMethodSymbolTableIteratorP[CallOffsetGetSymbol]);
        OrgTSortedThingList_SetSorted := GetCallTargetAddress(@CallAddrTSortedThingList_SetSortedP[CallOffsetSetSorted]);
      end
      else
      begin
        // No "disabled sorting" of the generated methods, but the insert position patch can still work
        CompleteMethodSymbolTableIteratorP := nil;
        CallAddrTSortedThingList_SetSortedP := nil;
      end;
    end;

    if (CompleteMethodSymbolTableIteratorP <> nil) and (CallAddrTSortedThingList_SetSortedP <> nil) then
    begin
      ReplaceRelCallOffset(@CompleteMethodSymbolTableIteratorP[CallOffsetTabCtor], @MethodSymbolTableIteratorFactory);
      ReplaceRelCallOffset(@CompleteMethodSymbolTableIteratorP[CallOffsetGetSymbol], @TTableIterator.GetSymbol);
      ReplaceRelCallOffset(@CallAddrTSortedThingList_SetSortedP[CallOffsetSetSorted], @TSortedThingList_SetSorted);
    end;

    if Assigned(OrgTClassSymbol_MethodAddPos) then
      RedirectOrg(@TClassSymbol_MethodAddPos, @TClassSymbol_MethodAddPos_AlphSort)
    else
      @OrgTClassSymbol_MethodAddPos := RedirectOrgCall(@TClassSymbol_MethodAddPos, @TClassSymbol_MethodAddPos_AlphSort);
  end
  else
  begin
    RestoreOrgCall(@TClassSymbol_MethodAddPos, @OrgTClassSymbol_MethodAddPos);
    if (CompleteMethodSymbolTableIteratorP <> nil) and (OrgTTableIterator_Ctor <> nil) then
      ReplaceRelCallOffset(@CompleteMethodSymbolTableIteratorP[CallOffsetTabCtor], OrgTTableIterator_Ctor);
    if (CompleteMethodSymbolTableIteratorP <> nil) and (OrgTTableIterator_GetSymbol <> nil) then
      ReplaceRelCallOffset(@CompleteMethodSymbolTableIteratorP[CallOffsetGetSymbol], OrgTTableIterator_GetSymbol);
    if (CallAddrTSortedThingList_SetSortedP <> nil) and (OrgTSortedThingList_SetSorted <> nil) then
      ReplaceRelCallOffset(@CallAddrTSortedThingList_SetSortedP[CallOffsetSetSorted], OrgTSortedThingList_SetSorted);
  end;
end;

{$ELSE} // not CPUX86

procedure InstallDisableAlphaSortClassCompletion(Value: Boolean);
begin
  // Win64: the IDE's class-completion routines live in 64-bit BPLs with a different
  // binary layout, so the byte-signature scanning and inline asm patches in this unit
  // do not apply. The feature is a no-op on Win64.
end;

{$ENDIF}

end.
