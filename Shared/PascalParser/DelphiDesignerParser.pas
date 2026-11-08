{******************************************************************************}
{*                                                                            *}
{* Delphi Designer Parser                                                     *}
{*                                                                            *}
{* (C) 2005 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

//TODO: Generics
//TODO: verify reference to procedure/function

unit DelphiDesignerParser;

/// <summary>
/// High-level Object Pascal parser used by IDE-extension features that need symbol-level
/// information (refactoring, code generators, the form designer). Builds a tree of TCodeSymbol
/// descendants (units, types, methods, fields, properties, local variables) that can be queried
/// by name and that retain source-location metadata for navigation. Built on top of
/// TDelphiPreprocessor / TDelphiLexer.
/// </summary>


interface

uses
  System.SysUtils, System.Classes, System.Contnrs, DelphiPreproc, DelphiLexer;

type
  /// <summary>Forward declaration of the class-list container.</summary>
  TCodeClassList = class;

  /// <summary>Discriminator for the kind of compilation unit (unit/program/library/package).</summary>
  TModuleType = (
    mtUnit, mtProgram, mtLibrary, mtPackage
  );

  /// <summary>Visibility of a class member (private/protected/public/published with strict variants).</summary>
  TAccessKind = (
    akPrivate, akStrictPrivate, akProtected, akStrictProtected,
    akPublic, akPublished
  );

  /// <summary>Virtual-table classification for a method (static/virtual/override/abstract/dynamic/message).</summary>
  TVirtualKind = (
    vkStatic, vkVirtual, vkOverride, vkAbstract, vkDynamic, vkMessage
  );

  /// <summary>Calling convention applied to a method or procedure pointer.</summary>
  TCallConvention = (
    ccRegister, ccStdCall, ccCdecl, ccPascal, ccSafecall
  );

  /// <summary>Parameter passing modifier (none / var / out / const).</summary>
  TArgModifier = (
    amNone, amVar, amOut, amConst
  );

  /// <summary>Kind of method being parsed (constructor/destructor/function/procedure).</summary>
  TMethodType = (
    mtConstructor, mtDestructor, mtFunction, mtProcedure
  );

  /// <summary>Hint that selects how the variable-list parser interprets the current declaration.</summary>
  TVarListMode = (
    vmFunctionArguments, vmFields, vmVariables
  );

  /// <summary>Source location captured by parser symbols (line, column, filename and absolute index).</summary>
  TLocation = record
    /// <summary>The source line and column of the token the location was taken from.</summary>
    Line, Column: Integer;
    /// <summary>The file the token came from (the parsed file or one of its include files); '' for no location.</summary>
    Filename: string;
    /// <summary>The token's linear character position in the text it was read from.</summary>
    Index: Integer;
  end;

  /// <summary>Base class for every parsed symbol; carries a name plus three source locations (start, name, end).</summary>
  TCodeSymbol = class(TObject)
  private
    /// <summary>Backing field for <see cref="Name"/>.</summary>
    FName: string;
    /// <summary>Backing field for <see cref="Access"/>; akPublished unless the parser sets a member's section.</summary>
    FAccess: TAccessKind;
    /// <summary>Backing field for <see cref="Location"/>.</summary>
    FLocation: TLocation;
    /// <summary>Backing field for <see cref="StartLocation"/>; set by the parser after construction.</summary>
    FStartLocation: TLocation;
    /// <summary>Backing field for <see cref="EndLocation"/>; set by the parser after construction.</summary>
    FEndLocation: TLocation;
  protected
    /// <summary>Finds the first symbol in List whose name matches AName, ignoring case.</summary>
    /// <param name="List">A list whose items are all TCodeSymbol descendants.</param>
    /// <param name="AName">The name to look for.</param>
    /// <returns>The first matching symbol, or nil when none matches.</returns>
    class function FindSymbol(List: TObjectList; const AName: string): TCodeSymbol;
  public
    /// <summary>Creates a symbol with the given name and name location; its access starts as akPublished.</summary>
    /// <param name="AName">The symbol's name.</param>
    /// <param name="ALocation">The location of the symbol's name in the source.</param>
    constructor Create(const AName: string; const ALocation: TLocation);

    /// <summary>Describes the symbol for display and debugging.</summary>
    /// <returns>The symbol's name.</returns>
    function ToString: string; override;

    /// <summary>The symbol's name as written in the source.</summary>
    property Name: string read FName;
    /// <summary>The location of the symbol's name.</summary>
    property Location: TLocation read FLocation;
    /// <summary>The location of the symbol's start (for example its PROCEDURE, PROPERTY or USES-item token).</summary>
    property StartLocation: TLocation read FStartLocation;
    /// <summary>The location of the symbol's end (the token that follows or closes its declaration).</summary>
    property EndLocation: TLocation read FEndLocation;
    /// <summary>The visibility section the member was declared in; akPublished for symbols that are not class members.</summary>
    property Access: TAccessKind read FAccess;
  end;

  /// <summary>Field of a class or record (also used as a base for local variables and method arguments).</summary>
  TCodeField = class(TCodeSymbol)
  private
    /// <summary>Backing field for <see cref="TypeName"/>.</summary>
    FTypeName: string;
    /// <summary>Backing field for <see cref="IsClassField"/>.</summary>
    FIsClassField: Boolean;
  protected
    /// <summary>
    /// Sets the type name once it is known: in <c>A, B: Integer</c> the names are read before the shared type, so every
    /// name of the group receives the type afterwards.
    /// </summary>
    /// <param name="ATypeName">The reformatted type name.</param>
    procedure SetTypeNameLater(const ATypeName: string);
  public
    /// <summary>Describes the field for display and debugging.</summary>
    /// <returns>The field in the form <c>Name: TypeName</c>.</returns>
    function ToString: string; override;

    /// <summary>The reformatted type as a string, e.g. <c>array[0..20] of string</c>.</summary>
    property TypeName: string read FTypeName;
    /// <summary>True if the field is a class variable (declared with <c>class var</c>, static).</summary>
    property IsClassField: Boolean read FIsClassField;
  end;

  /// <summary>Class property declaration with getter/setter/storage information.</summary>
  TCodeProperty = class(TCodeSymbol)
  private
    /// <summary>Backing field for <see cref="TypeName"/>.</summary>
    FTypeName: string;
    /// <summary>Backing field for <see cref="Setter"/>.</summary>
    FSetter: string;
    /// <summary>Backing field for <see cref="Adder"/>.</summary>
    FAdder: string;
    /// <summary>Backing field for <see cref="IsDefault"/>.</summary>
    FIsDefault: Boolean;
    /// <summary>Backing field for <see cref="Remover"/>.</summary>
    FRemover: string;
    /// <summary>Backing field for <see cref="Storer"/>.</summary>
    FStorer: string;
    /// <summary>Backing field for <see cref="Getter"/>.</summary>
    FGetter: string;
    /// <summary>Backing field for <see cref="IsArray"/>.</summary>
    FIsArray: Boolean;
    /// <summary>Backing field for <see cref="IsClassProperty"/>.</summary>
    FIsClassProperty: Boolean;
    /// <summary>Backing field for <see cref="IsInheritChange"/>.</summary>
    FIsInheritChange: Boolean;
    /// <summary>Backing field for <see cref="IsNoDefault"/>.</summary>
    FIsNoDefault: Boolean;
  public
    /// <summary>Describes the property for display and debugging.</summary>
    /// <returns>
    /// The property in declaration form, e.g. <c>Name[]: TypeName read GetX write SetX; default</c>, listing only the parts
    /// that were declared.
    /// </returns>
    function ToString: string; override;

    /// <summary>The reformatted type as a string, e.g. <c>array[0..20] of string</c>; '' when <see cref="IsInheritChange"/>.</summary>
    property TypeName: string read FTypeName;
    /// <summary>The name after READ (field or method), or '' if there is none.</summary>
    property Getter: string read FGetter;
    /// <summary>The name after WRITE (field or method), or '' if there is none.</summary>
    property Setter: string read FSetter;
    /// <summary>The name after ADD (.NET event adder), or '' if there is none.</summary>
    property Adder: string read FAdder;
    /// <summary>The name after REMOVE (.NET event remover), or '' if there is none.</summary>
    property Remover: string read FRemover;
    /// <summary>The identifier after STORED, or '' if there is none (or it is not an identifier).</summary>
    property Storer: string read FStorer;
    /// <summary>True if the property is the class's default array property (<c>; default</c> after the declaration).</summary>
    property IsDefault: Boolean read FIsDefault;
    /// <summary>True if the declaration ends with <c>; nodefault</c>.</summary>
    property IsNoDefault: Boolean read FIsNoDefault;
    /// <summary>True if the property is an array property (it has an index parameter list).</summary>
    property IsArray: Boolean read FIsArray;
    /// <summary>True if the property is declared with <c>class property</c>.</summary>
    property IsClassProperty: Boolean read FIsClassProperty;
    /// <summary>
    /// True if the property redeclares an inherited one without a type (no colon after the name), to change its
    /// visibility or default value.
    /// </summary>
    property IsInheritChange: Boolean read FIsInheritChange;
  end;

  /// <summary>Local variable inside a procedure or function: a TCodeField descendant that adds nothing, kept as its own class for clarity.</summary>
  TCodeLocalVariable = class(TCodeField)
  end;

  /// <summary>Argument of a method, including the parameter modifier (var/out/const/none).</summary>
  TCodeMethodArg = class(TCodeField)
  private
    /// <summary>Backing field for <see cref="Modifier"/>.</summary>
    FModifier: TArgModifier;
  public
    /// <summary>Describes the parameter for display and debugging.</summary>
    /// <returns>The parameter in the form <c>[var |out |const ]Name: TypeName</c>.</returns>
    function ToString: string; override;

    /// <summary>The parameter modifier (none, var, out, const).</summary>
    property Modifier: TArgModifier read FModifier;
  end;

  /// <summary>
  /// Method, procedure or function declaration. Tracks both the interface declaration and the
  /// implementation body so callers can navigate between them and find safe insertion locations
  /// for new local variables or generated code.
  /// </summary>
  TCodeMethod = class(TCodeSymbol)
  private
    /// <summary>Owns the parameters (TCodeMethodArg) in declaration order; backs <see cref="Args"/>.</summary>
    FArgs: TObjectList;
    /// <summary>Backing field for <see cref="CodeInsert"/>.</summary>
    FCodeInsert: TLocation;
    /// <summary>The location of the implementation's local VAR keyword (the last one met), where new local variables can go.</summary>
    FVarInsert: TLocation;
    /// <summary>Owns the implementation's local variables (TCodeLocalVariable); backs <see cref="LocalVariables"/>.</summary>
    FLocalVariables: TObjectList;
    /// <summary>Owns the implementation's nested procedures and functions (TCodeMethod); backs <see cref="LocalProcss"/>.</summary>
    FLocalProcs: TObjectList;
    /// <summary>Backing field for <see cref="ImplLocation"/>.</summary>
    FImplLocation: TLocation;
    /// <summary>Backing field for <see cref="ReturnTypeName"/>.</summary>
    FReturnTypeName: string;
    /// <summary>Backing field for <see cref="IsClassStatic"/>.</summary>
    FIsClassStatic: Boolean;
    /// <summary>Backing field for <see cref="IsClassMethod"/>.</summary>
    FIsClassMethod: Boolean;
    /// <summary>Backing field for <see cref="VirtualKind"/>.</summary>
    FVirtualKind: TVirtualKind;
    /// <summary>Backing field for <see cref="Convention"/>.</summary>
    FConvention: TCallConvention;
    /// <summary>Backing field for <see cref="MethodType"/>.</summary>
    FMethodType: TMethodType;
    /// <summary>Backing field for <see cref="IsImplemented"/>.</summary>
    FIsImplemented: Boolean;
    /// <summary>Backing field for <see cref="IsDeclared"/>.</summary>
    FIsDeclared: Boolean;
    /// <summary>Backing field for <see cref="ImplEndLocation"/>.</summary>
    FImplEndLocation: TLocation;
    /// <summary>Backing field for <see cref="ImplBeginLocation"/>.</summary>
    FImplBeginLocation: TLocation;
    /// <summary>Backing field for <see cref="IsImplEmpty"/>.</summary>
    FIsImplEmpty: Boolean;
    /// <summary>Read accessor for <see cref="Args"/>.</summary>
    /// <param name="Index">The 0-based parameter index.</param>
    /// <returns>The parameter at Index.</returns>
    function GetArg(Index: Integer): TCodeMethodArg;
    /// <summary>Read accessor for <see cref="ArgCount"/>.</summary>
    /// <returns>The number of parameters.</returns>
    function GetArgCount: Integer;
    /// <summary>Read accessor for <see cref="LocalVariables"/>.</summary>
    /// <param name="Index">The 0-based local-variable index.</param>
    /// <returns>The local variable at Index.</returns>
    function GetLocalVariable(Index: Integer): TCodeLocalVariable;
    /// <summary>Read accessor for <see cref="LocalVariableCount"/>.</summary>
    /// <returns>The number of local variables.</returns>
    function GetLocalVariableCount: Integer;
    /// <summary>Read accessor for <see cref="LocalProcss"/>.</summary>
    /// <param name="Index">The 0-based local-procedure index.</param>
    /// <returns>The local procedure at Index.</returns>
    function GetLocalProc(Index: Integer): TCodeMethod;
    /// <summary>Read accessor for <see cref="LocalProcCount"/>.</summary>
    /// <returns>The number of local procedures.</returns>
    function GetLocalProcCount: Integer;
  protected
    /// <summary>Appends a parameter; the method takes ownership of it.</summary>
    /// <param name="Item">The parameter to add.</param>
    /// <returns>The index of the added parameter.</returns>
    function AddArg(Item: TCodeMethodArg): Integer;
    /// <summary>Appends a local variable; the method takes ownership of it.</summary>
    /// <param name="Item">The local variable to add.</param>
    /// <returns>The index of the added local variable.</returns>
    function AddLocalVariable(Item: TCodeLocalVariable): Integer;
    /// <summary>Appends a nested procedure or function; the method takes ownership of it.</summary>
    /// <param name="Item">The local procedure to add.</param>
    /// <returns>The index of the added local procedure.</returns>
    function AddLocalProc(Item: TCodeMethod): Integer;
  public
    /// <summary>Creates a method with empty parameter, local-variable and local-procedure lists.</summary>
    /// <param name="AName">The method's name (without the class qualifier).</param>
    /// <param name="ALocation">The location of the method's name in its declaration (EmptyLocation when only the implementation was found).</param>
    constructor Create(const AName: string; const ALocation: TLocation);
    /// <summary>Frees the method together with its parameters, local variables and local procedures.</summary>
    destructor Destroy; override;

    /// <summary>Describes the method for display and debugging.</summary>
    /// <returns>The signature, e.g. <c>function Name(const A: Integer; B: string): Boolean</c>.</returns>
    function ToString: string; override;

    /// <summary>Finds a parameter by name, ignoring case.</summary>
    /// <param name="AName">The parameter name to look for.</param>
    /// <returns>The matching parameter, or nil if no parameter has that name.</returns>
    function FindArg(const AName: string): TCodeMethodArg;

    /// <summary>
    /// Tells whether M has the same signature: method type, calling convention, class/static flags, return type and the
    /// modifier and type of every parameter.  Names (method and parameters) are not compared.
    /// </summary>
    /// <param name="M">The method to compare with; nil is never compatible, Self always is.</param>
    /// <returns>True if both methods have the same signature.</returns>
    function IsCompatible(M: TCodeMethod): Boolean;

    /// <summary>The location of the method's name in its implementation.</summary>
    property ImplLocation: TLocation read FImplLocation;
    /// <summary>The location of the implementation's start (its PROCEDURE/FUNCTION/... keyword, or CLASS before it).</summary>
    property ImplBeginLocation: TLocation read FImplBeginLocation;
    /// <summary>The location of the token after the implementation's closing END.</summary>
    property ImplEndLocation: TLocation read FImplEndLocation;
    /// <summary>True if the implementation has no local declarations and its body is only <c>begin end</c>.</summary>
    property IsImplEmpty: Boolean read FIsImplEmpty;
    /// <summary>The location of the first token after BEGIN in the implementation, where generated code can be inserted.</summary>
    property CodeInsert: TLocation read FCodeInsert;

    /// <summary>The kind of method (constructor, destructor, function, procedure).</summary>
    property MethodType: TMethodType read FMethodType;
    /// <summary>The reformatted return type as a string, e.g. <c>array[0..20] of string</c>; '' for a procedure.</summary>
    property ReturnTypeName: string read FReturnTypeName;
    /// <summary>True if the method is a class method.</summary>
    property IsClassMethod: Boolean read FIsClassMethod;
    /// <summary>True if the method is a static class method (has the STATIC directive).</summary>
    property IsClassStatic: Boolean read FIsClassStatic;
    /// <summary>The method's virtuality kind (static, virtual, override, abstract, dynamic, message).</summary>
    property VirtualKind: TVirtualKind read FVirtualKind;
    /// <summary>The method's calling convention.</summary>
    property Convention: TCallConvention read FConvention;

    /// <summary>
    /// True if an implementation of the method was found.  If IsDeclared &lt;&gt; IsImplemented, one of the two is
    /// missing.
    /// </summary>
    property IsImplemented: Boolean read FIsImplemented;
    /// <summary>True if the method was found in a class declaration.</summary>
    property IsDeclared: Boolean read FIsDeclared;

    /// <summary>The number of parameters.</summary>
    property ArgCount: Integer read GetArgCount;
    /// <summary>The parameters, in declaration order.</summary>
    /// <param name="Index">The 0-based parameter index.</param>
    property Args[Index: Integer]: TCodeMethodArg read GetArg;

    /// <summary>The number of local variables in the implementation.</summary>
    property LocalVariableCount: Integer read GetLocalVariableCount;
    /// <summary>The local variables declared in the implementation's VAR sections.</summary>
    /// <param name="Index">The 0-based local-variable index.</param>
    property LocalVariables[Index: Integer]: TCodeLocalVariable read GetLocalVariable;

    /// <summary>The number of local (nested) procedures in the implementation.</summary>
    property LocalProcCount: Integer read GetLocalProcCount;
    /// <summary>The local (nested) procedures and functions of the implementation.</summary>
    /// <param name="Index">The 0-based local-procedure index.</param>
    property LocalProcss[Index: Integer]: TCodeMethod read GetLocalProc;
  end;

  /// <summary>Class declaration: base class, supported interfaces, fields, properties and methods.</summary>
  TCodeClass = class(TCodeSymbol)
  private
    /// <summary>Backing field for <see cref="AccessInsert"/>; an entry with an empty Filename has not been recorded.</summary>
    FAccessInsert: array[TAccessKind] of TLocation;
    /// <summary>Backing field for <see cref="BaseClass"/>.</summary>
    FBaseClass: string;
    /// <summary>Backing field for <see cref="IsUnitPrivate"/>.</summary>
    FIsUnitPrivate: Boolean;

    /// <summary>The names of the directly implemented interfaces; backs <see cref="Interfaces"/>.</summary>
    FInterfaces: TStringList;
    /// <summary>Owns the class's fields (TCodeField); backs <see cref="Fields"/>.</summary>
    FFields: TObjectList;
    /// <summary>Owns the class's properties (TCodeProperty); backs <see cref="Properties"/>.</summary>
    FProperties: TObjectList;
    /// <summary>Owns the class's methods (TCodeMethod); backs <see cref="Methods"/>.</summary>
    FMethods: TObjectList;

    /// <summary>Read accessor for <see cref="InterfaceCount"/>.</summary>
    /// <returns>The number of directly implemented interfaces.</returns>
    function GetInterfaceCount: Integer;
    /// <summary>Read accessor for <see cref="Interfaces"/>.</summary>
    /// <param name="Index">The 0-based interface index.</param>
    /// <returns>The interface name at Index.</returns>
    function GetInterfaceItem(Index: Integer): string;
    /// <summary>Read accessor for <see cref="AccessInsert"/>.</summary>
    /// <param name="Access">The visibility section.</param>
    /// <returns>The recorded insert location for that section, or a location with an empty Filename if none was recorded.</returns>
    function GetAccessInsert(Access: TAccessKind): TLocation;
    /// <summary>Read accessor for <see cref="Fields"/>.</summary>
    /// <param name="Index">The 0-based field index.</param>
    /// <returns>The field at Index.</returns>
    function GetField(Index: Integer): TCodeField;
    /// <summary>Read accessor for <see cref="FieldCount"/>.</summary>
    /// <returns>The number of fields.</returns>
    function GetFieldCount: Integer;
    /// <summary>Read accessor for <see cref="MethodCount"/>.</summary>
    /// <returns>The number of methods.</returns>
    function GetMethodCount: Integer;
    /// <summary>Read accessor for <see cref="Methods"/>.</summary>
    /// <param name="Index">The 0-based method index.</param>
    /// <returns>The method at Index.</returns>
    function GetMethodItem(Index: Integer): TCodeMethod;
    /// <summary>Read accessor for <see cref="Properties"/>.</summary>
    /// <param name="Index">The 0-based property index.</param>
    /// <returns>The property at Index.</returns>
    function GetProperty(Index: Integer): TCodeProperty;
    /// <summary>Read accessor for <see cref="PropertyCount"/>.</summary>
    /// <returns>The number of properties.</returns>
    function GetPropertyCount: Integer;
  protected
    /// <summary>Records the name of a directly implemented interface.</summary>
    /// <param name="Item">The interface name.</param>
    /// <returns>The index of the added name.</returns>
    function AddInterface(const Item: string): Integer;
    /// <summary>Appends a field; the class takes ownership of it.</summary>
    /// <param name="Item">The field to add.</param>
    /// <returns>The index of the added field.</returns>
    function AddField(Item: TCodeField): Integer;
    /// <summary>Appends a property; the class takes ownership of it.</summary>
    /// <param name="Item">The property to add.</param>
    /// <returns>The index of the added property.</returns>
    function AddProperty(Item: TCodeProperty): Integer;
    /// <summary>Appends a method; the class takes ownership of it.</summary>
    /// <param name="Item">The method to add.</param>
    /// <returns>The index of the added method.</returns>
    function AddMethod(Item: TCodeMethod): Integer;
  public
    /// <summary>Creates a class symbol with empty interface, field, property and method lists.</summary>
    /// <param name="AName">The class's name.</param>
    /// <param name="ALocation">The location of the class's name in its declaration.</param>
    constructor Create(const AName: string; const ALocation: TLocation);
    /// <summary>Frees the class together with its interface names, fields, properties and methods.</summary>
    destructor Destroy; override;

    /// <summary>Tells whether the class lists the interface directly in its declaration (inherited ones are not seen).</summary>
    /// <param name="AName">The interface name, as written in the class declaration.</param>
    /// <returns>True if the class implements the interface directly.</returns>
    function SupportsInterface(const AName: string): Boolean;
    /// <summary>Finds a property by name, ignoring case.</summary>
    /// <param name="AName">The property name.</param>
    /// <returns>The matching property, or nil if none was found.</returns>
    function FindProperty(const AName: string): TCodeProperty;
    /// <summary>Finds a field by name, ignoring case.</summary>
    /// <param name="AName">The field name.</param>
    /// <returns>The matching field, or nil if none was found.</returns>
    function FindField(const AName: string): TCodeField;
    /// <summary>Finds the first method with the given name, ignoring case (overloads are not told apart).</summary>
    /// <param name="AName">The method name.</param>
    /// <returns>The first matching method, or nil if none was found.</returns>
    function FindMethod(const AName: string): TCodeMethod;

    /// <summary>
    /// The location where members of the given visibility section can be inserted: the token at which the first section of
    /// that kind ends (the next visibility keyword).  Its Filename is empty if no such section ended there.
    /// </summary>
    /// <param name="Access">The visibility section (private, public, ...).</param>
    property AccessInsert[Access: TAccessKind]: TLocation read GetAccessInsert;

    /// <summary>The name of the base class; TObject when the declaration names none.</summary>
    property BaseClass: string read FBaseClass;
    /// <summary>True if the class is declared in the implementation section.</summary>
    property IsUnitPrivate: Boolean read FIsUnitPrivate;

    /// <summary>The number of directly implemented interfaces.</summary>
    property InterfaceCount: Integer read GetInterfaceCount;
    /// <summary>The names of the directly implemented interfaces, in declaration order.</summary>
    /// <param name="Index">The 0-based interface index.</param>
    property Interfaces[Index: Integer]: string read GetInterfaceItem;

    /// <summary>The number of member methods.</summary>
    property MethodCount: Integer read GetMethodCount;
    /// <summary>The member methods (declared, plus implemented ones with no matching declaration).</summary>
    /// <param name="Index">The 0-based method index.</param>
    property Methods[Index: Integer]: TCodeMethod read GetMethodItem;

    /// <summary>The number of member properties.</summary>
    property PropertyCount: Integer read GetPropertyCount;
    /// <summary>The member properties, in declaration order.</summary>
    /// <param name="Index">The 0-based property index.</param>
    property Properties[Index: Integer]: TCodeProperty read GetProperty;

    /// <summary>The number of member fields.</summary>
    property FieldCount: Integer read GetFieldCount;
    /// <summary>The member fields, in declaration order.</summary>
    /// <param name="Index">The 0-based field index.</param>
    property Fields[Index: Integer]: TCodeField read GetField;
  end;

  /// <summary>Owned collection of TCodeClass instances with name-based look-up.</summary>
  TCodeClassList = class(TObject)
  private
    /// <summary>Owns the classes (TCodeClass); backs <see cref="Items"/>.</summary>
    FItems: TObjectList;
    /// <summary>Read accessor for <see cref="Items"/>.</summary>
    /// <param name="Index">The 0-based class index.</param>
    /// <returns>The class at Index.</returns>
    function GetItem(Index: Integer): TCodeClass;
    /// <summary>Read accessor for <see cref="Count"/>.</summary>
    /// <returns>The number of classes.</returns>
    function GetCount: Integer;
  protected
    /// <summary>Removes and frees every class.</summary>
    procedure Clear;
    /// <summary>Appends a class; the list takes ownership of it.</summary>
    /// <param name="Item">The class to add.</param>
    /// <returns>The index of the added class.</returns>
    function Add(Item: TCodeClass): Integer;
  public
    /// <summary>Creates an empty class list.</summary>
    constructor Create;
    /// <summary>Frees the list and every class in it.</summary>
    destructor Destroy; override;

    /// <summary>Finds a class by name, ignoring case.</summary>
    /// <param name="ClassName">The class name.</param>
    /// <returns>The first matching class, or nil if the class was not found.</returns>
    function Find(const ClassName: string): TCodeClass;

    /// <summary>The number of classes.</summary>
    property Count: Integer read GetCount;
    /// <summary>The classes, in the order the parser found them.</summary>
    /// <param name="Index">The 0-based class index.</param>
    property Items[Index: Integer]: TCodeClass read GetItem; default;
  end;

  /// <summary>Single entry in a uses/contains/requires clause: unit name plus an optional "in 'file.pas'" filename.</summary>
  TUsesItem = class(TCodeSymbol)
  private
    /// <summary>Backing field for <see cref="Filename"/>.</summary>
    FFilename: string;
  public
    /// <summary>Creates a uses entry.</summary>
    /// <param name="AName">The (possibly dotted) unit name.</param>
    /// <param name="AFilename">The filename given with IN, unquoted, or '' if none was given.</param>
    /// <param name="ALocation">The location of the unit name.</param>
    constructor Create(const AName, AFilename: string; const ALocation: TLocation);

    /// <summary>The included unit name (dotted names are kept whole).</summary>
    property Name;

    /// <summary>The filename given with IN (<c>bla in 'bla.pas'</c>), unquoted; '' if no filename was given.</summary>
    property Filename: string read FFilename;
  end;

  /// <summary>Collection of TUsesItem entries that also captures the source location of the surrounding clause.</summary>
  TUsesList = class(TObject)
  private
    /// <summary>Owns the entries (TUsesItem); backs <see cref="Items"/>.</summary>
    FItems: TObjectList;
    /// <summary>Backing field for <see cref="Location"/>.</summary>
    FLocation: TLocation;
    /// <summary>Backing field for <see cref="EndLocation"/>.</summary>
    FEndLocation: TLocation;
    /// <summary>Read accessor for <see cref="Count"/>.</summary>
    /// <returns>The number of entries.</returns>
    function GetCount: Integer;
    /// <summary>Read accessor for <see cref="Items"/>.</summary>
    /// <param name="Index">The 0-based entry index.</param>
    /// <returns>The entry at Index.</returns>
    function GetItem(Index: Integer): TUsesItem;
  protected
    /// <summary>Removes and frees every entry; the locations are left as they are.</summary>
    procedure Clear;
    /// <summary>Appends an entry; the list takes ownership of it.</summary>
    /// <param name="Item">The entry to add.</param>
    /// <returns>The index of the added entry.</returns>
    function AddUses(Item: TUsesItem): Integer;
  public
    /// <summary>Creates an empty uses list.</summary>
    constructor Create;
    /// <summary>Frees the list and every entry in it.</summary>
    destructor Destroy; override;

    /// <summary>Finds an entry by unit name, ignoring case.</summary>
    /// <param name="AName">The unit name.</param>
    /// <returns>The first matching entry, or nil if no matching USES-item was found.</returns>
    function FindUses(const AName: string): TUsesItem;
    /// <summary>Finds the position of an entry object in the list.</summary>
    /// <param name="AItem">The entry to look for (compared by reference).</param>
    /// <returns>The 0-based index of AItem, or -1 if it is not in the list.</returns>
    function IndexOf(AItem: TUsesItem): Integer;

    /// <summary>The number of entries.</summary>
    property Count: Integer read GetCount;
    /// <summary>The entries, in clause order.</summary>
    /// <param name="Index">The 0-based entry index.</param>
    property Items[Index: Integer]: TUsesItem read GetItem; default;

    /// <summary>The location of the USES (or REQUIRES / CONTAINS) keyword.</summary>
    property Location: TLocation read FLocation;
    /// <summary>The location of the semicolon that ends the clause.</summary>
    property EndLocation: TLocation read FEndLocation;
  end;

  /// <summary>
  /// Fast structural parser. Rather than building a full AST it scans for the keywords needed by
  /// the form designer (unit/program/library/package, uses, class, property, function, ...) and
  /// captures sufficient location data to navigate, refactor and generate code.
  /// </summary>
  TDesignerParser = class(TObject)
  private
    /// <summary>The token source while a parse runs; created by ParseHead and freed (set to nil) when the parse ends or fails.</summary>
    p: TDelphiPreprocessor;
    /// <summary>True once the IMPLEMENTATION keyword has been passed.</summary>
    FImplementation: Boolean;
    /// <summary>Backing field for <see cref="Classes"/>.</summary>
    FClasses: TCodeClassList;
    /// <summary>Backing field for <see cref="ModuleName"/>.</summary>
    FModuleName: string;
    /// <summary>Backing field for <see cref="FormResource"/>.</summary>
    FFormResource: string;
    /// <summary>Backing field for <see cref="Filename"/>.</summary>
    FFilename: string;
    /// <summary>Backing field for <see cref="Text"/>.</summary>
    FText: UTF8String;
    /// <summary>When True, the next call to Next hands back the current token again instead of reading a new one.</summary>
    FRepeatLastToken: Boolean;
    /// <summary>Backing field for <see cref="ImplUses"/>.</summary>
    FImplUses: TUsesList;
    /// <summary>Backing field for <see cref="InterfaceUses"/>.</summary>
    FInterfaceUses: TUsesList;
    /// <summary>Backing field for <see cref="ImplLocation"/>.</summary>
    FImplLocation: TLocation;
    /// <summary>Backing field for <see cref="InterfaceLocation"/>.</summary>
    FInterfaceLocation: TLocation;
    /// <summary>The $R resource names found; backs <see cref="Resources"/>.</summary>
    FResources: TStringList;
    /// <summary>The $I / $INCLUDE file names found, unquoted; backs <see cref="IncludeFiles"/>.</summary>
    FIncludeFiles: TStringList;
    /// <summary>Backing field for <see cref="Contains"/>.</summary>
    FContains: TUsesList;
    /// <summary>Backing field for <see cref="Requires"/>.</summary>
    FRequires: TUsesList;
    /// <summary>Backing field for <see cref="ModuleType"/>.</summary>
    FModuleType: TModuleType;
    /// <summary>Owns the stand-alone routines (TCodeMethod) found in the implementation section; backs <see cref="Functions"/>.</summary>
    FFunctions: TObjectList;
    /// <summary>Backing field for <see cref="IncludeDirs"/>.</summary>
    FIncludeDirs: TStrings;
    /// <summary>Backing field for <see cref="ParseError"/>.</summary>
    FParseError: Boolean;

    /// <summary>
    /// OnIncludeFile handler: records the include file in <see cref="IncludeFiles"/> and loads it into the preprocessor.  A
    /// file that exists but cannot be read (EStreamError, EOSError) sets <see cref="ParseError"/> instead of raising.
    /// </summary>
    /// <param name="Sender">The TDelphiPreprocessor that met the include directive.</param>
    /// <param name="Name">The include file name as written, possibly quoted.</param>
    procedure IncludeFile(Sender: TObject; const Name: string);
    /// <summary>Finds the include file LName (beside the current file, then in IncludeDirs) and hands its text to Preprocessor.</summary>
    /// <param name="Preprocessor">The preprocessor that met the include directive.</param>
    /// <param name="LName">The include file name, unquoted.</param>
    /// <exception cref="EFOpenError">Raised when the file exists but cannot be opened.</exception>
    procedure IncludeFoundFile(Preprocessor: TDelphiPreprocessor; const LName: string);
    /// <summary>
    /// OnDirective handler: records every <c>{$R ...}</c> resource in <see cref="Resources"/>, and a form resource
    /// (<c>*.dfm</c>, <c>*.fmx</c>, <c>*.nfm</c>, <c>*.xfm</c>, <c>*.lfm</c>) also in <see cref="FormResource"/>.
    /// </summary>
    /// <param name="Sender">The preprocessor that met the directive.</param>
    /// <param name="Token">The directive's comment token, braces or <c>(* *)</c> included.</param>
    procedure Directive(Sender: TObject; Token: TToken);
    /// <summary>
    /// OnGetDeclared handler for <c>Declared()</c>: a name counts as declared when it is a unit in either uses clause, a
    /// class or a stand-alone routine found so far.
    /// </summary>
    /// <param name="Sender">The preprocessor that evaluates the expression.</param>
    /// <param name="Name">The identifier passed to <c>Declared()</c>.</param>
    /// <param name="Value">Receives True if the name is declared.</param>
    procedure GetDeclared(Sender: TObject; const Name: string; var Value: Boolean);
    /// <summary>OnGetConstValue handler: supplies <c>CompilerVersion</c> as a float; any other name is left unchanged.</summary>
    /// <param name="Sender">The preprocessor that evaluates the expression.</param>
    /// <param name="Name">The constant's name.</param>
    /// <param name="Kind">Receives tkFloat for <c>CompilerVersion</c>.</param>
    /// <param name="Value">Receives the compiler version, e.g. <c>37.0</c>, for <c>CompilerVersion</c>.</param>
    procedure GetConstValue(Sender: TObject; const Name: string; var Kind: TTokenKind; var Value: string);
    /// <summary>OnGetConstBoolValue handler: does nothing, so Value keeps whatever the preprocessor passed in.</summary>
    /// <param name="Sender">The preprocessor that evaluates the expression.</param>
    /// <param name="Name">The constant's name.</param>
    /// <param name="Value">Left unchanged.</param>
    procedure GetConstBoolValue(Sender: TObject; const Name: string; var Value: Boolean);

    /// <summary>
    /// Resets every result (uses lists, resources, include files, classes, functions, module name and type, locations,
    /// <see cref="ParseError"/>) before a new parse.  <see cref="IncludeDirs"/> is kept.
    /// </summary>
    procedure Clear;

    /// <summary>Gives the current token without advancing.</summary>
    /// <returns>The preprocessor's current token; nil at the end of the text.</returns>
    function Look: TToken;
    /// <summary>
    /// Advances to the next token, or, when FRepeatLastToken is set, clears it and stays on the current token.
    /// </summary>
    /// <returns>False at the end of the text, or when the preprocessor was dropped after an error.</returns>
    function Next: Boolean;
    /// <summary>Advances like <see cref="Next"/>, but aborts the parse at the end of the text.</summary>
    /// <exception cref="EAbort">Raised (through Abort) when there is no next token; Parse and ParseUsesOnly absorb it.</exception>
    procedure NextA;
    /// <summary>
    /// Skips a routine, a routine type or an anonymous method from its PROCEDURE/FUNCTION/... keyword: its name,
    /// parameters, return type, directives and, in the implementation section, its body.
    /// </summary>
    procedure IgnoreProc;
    /// <summary>Skips a record, object or interface type (and any type nested in it) up to its END, or a forward declaration.</summary>
    procedure IgnoreRecord;
    /// <summary>Skips an interface type; the same as <see cref="IgnoreRecord"/>.</summary>
    procedure IgnoreInterface;
    /// <summary>
    /// Skips a BEGIN ... END (or the rest of one) up to its matching END, counting nested BEGIN, CASE and TRY blocks.
    /// </summary>
    /// <param name="Empty">Receives True if the block contains no tokens between BEGIN and END.</param>
    /// <returns>The location of the first token after BEGIN.</returns>
    function IgnoreBlock(out Empty: Boolean): TLocation;
    /// <summary>
    /// Skips a nested TYPE or CONST section in a class up to the next visibility keyword or END.  At the end of the text it
    /// aborts the parse through <see cref="NextA"/>.
    /// </summary>
    /// <exception cref="EAbort">Raised when the text ends before a visibility keyword or END.</exception>
    procedure IgnoreToClassAccess;
    /// <summary>Skips the rest of an EXTERNAL directive (library, NAME, INDEX and string expressions).</summary>
    procedure IgnoreExternal;
    /// <summary>
    /// Skips a procedural type or variable (<c>X: procedure(...)</c>, <c>T = function(...): ...</c>), including
    /// <c>of object</c> and the closing semicolon.
    /// </summary>
    procedure IgnoreFunctionType;
    /// <summary>
    /// Parses a class declaration whose CLASS keyword has just been read: base class, interfaces, and the fields,
    /// properties and methods of each visibility section, and adds it to <see cref="Classes"/>.  A declaration that
    /// cannot be read (the text ends, or there is no type name) is skipped.
    /// </summary>
    procedure ParseClass;
    /// <summary>Parses a method declaration in a class and adds it to the class's methods.</summary>
    /// <param name="C">The class being parsed.</param>
    /// <param name="Access">The visibility section the declaration is in.</param>
    /// <param name="IsClass">True if the declaration is preceded by CLASS.</param>
    procedure ParseMethodDecl(C: TCodeClass; Access: TAccessKind; IsClass: Boolean);
    /// <summary>Parses a property declaration (type, accessors, STORED, DEFAULT/NODEFAULT) and adds it to the class's properties.</summary>
    /// <param name="C">The class being parsed.</param>
    /// <param name="Access">The visibility section the declaration is in.</param>
    /// <param name="IsClass">True if the declaration is preceded by CLASS.</param>
    procedure ParseProperty(C: TCodeClass; Access: TAccessKind; IsClass: Boolean);
    /// <summary>Parses a field declaration (one or more comma-separated names) and adds the fields to the class.</summary>
    /// <param name="C">The class being parsed.</param>
    /// <param name="Access">The visibility section the declaration is in.</param>
    /// <param name="IsClass">True for a class variable.</param>
    procedure ParseField(C: TCodeClass; Access: TAccessKind; IsClass: Boolean);
    /// <summary>
    /// Reads a type expression and reformats it as a string: a qualified name, <c>array[...] of ...</c>,
    /// <c>set of ...</c>; record, object and procedural types are skipped.  An unreadable type gives
    /// <c>errornous</c>.
    /// </summary>
    /// <param name="Stop">The tokens that end the type; passed on to the element type of an array.</param>
    /// <returns>The reformatted type name.</returns>
    function ParseTypeName(const Stop: TTokenKindSet): string;
    /// <summary>Parses a parenthesised parameter list into M's parameters.</summary>
    /// <param name="M">The method that receives the parameters, or nil to skip the list.</param>
    procedure ParseFunctionArgs(M: TCodeMethod);
    /// <summary>Parses a USES, REQUIRES or CONTAINS clause from its keyword up to the closing semicolon.</summary>
    /// <param name="List">Receives the entries and the clause's locations.</param>
    procedure ParseUses(List: TUsesList);
    /// <summary>
    /// Parses a routine heading met outside a class declaration, matches it with the declared method (or earlier stand-alone
    /// routine) of the same signature and records its implementation: locations, local variables, nested routines and the
    /// code-insert point.  An unmatched method of a class is added to the class; an unmatched stand-alone routine in the
    /// implementation section is added to <see cref="Functions"/>.  Procedural types and variables are skipped.
    /// </summary>
    /// <param name="AParent">The routine this one is nested in, or nil for a top-level routine.</param>
    procedure ParseFunctionImpl(AParent: TCodeMethod);
    /// <summary>
    /// Reads the directives after a routine heading (STATIC, VIRTUAL, OVERRIDE, ..., calling conventions, EXTERNAL) into M,
    /// stopping at the first token that is not a directive.
    /// </summary>
    /// <param name="M">The method that receives the directives.</param>
    procedure ParseDirectives(M: TCodeMethod);
    /// <summary>
    /// Parses a list of <c>Name[, Name]: Type;</c> declarations, as parameters, class fields or local variables.
    /// </summary>
    /// <param name="List">
    /// Receives a TCodeMethodArg (parameters) or TCodeField (otherwise) per name, or nil to only skip the declarations.
    /// </param>
    /// <param name="Mode">What is being parsed, which decides the item class and the tokens that end the list.</param>
    procedure ParseVariableList(List: TObjectList; Mode: TVarListMode);
    /// <summary>Parses the declarations of a VAR section into List (vmVariables mode).</summary>
    /// <param name="List">Receives a TCodeField per declared name.</param>
    procedure ParseVariableDecl(List: TObjectList);

    /// <summary>Read accessor for <see cref="Resources"/>.</summary>
    /// <param name="Index">The 0-based resource index.</param>
    /// <returns>The resource name at Index.</returns>
    function GetResource(Index: Integer): string;
    /// <summary>Read accessor for <see cref="ResourceCount"/>.</summary>
    /// <returns>The number of resources.</returns>
    function GetResourceCount: Integer;
    /// <summary>Read accessor for <see cref="IncludeFiles"/>.</summary>
    /// <param name="Index">The 0-based include-file index.</param>
    /// <returns>The include file name at Index.</returns>
    function GetIncludeFiles(Index: Integer): string;
    /// <summary>Read accessor for <see cref="IncludeFileCount"/>.</summary>
    /// <returns>The number of include files.</returns>
    function GetIncludeFileCount: Integer;

    /// <summary>Read accessor for <see cref="FunctionCount"/>.</summary>
    /// <returns>The number of stand-alone routines.</returns>
    function GetFunctionCount: Integer;
    /// <summary>Read accessor for <see cref="Functions"/>.</summary>
    /// <param name="Index">The 0-based routine index.</param>
    /// <returns>The routine at Index.</returns>
    function GetFunctionItem(Index: Integer): TCodeMethod;
    /// <summary>Appends a stand-alone routine; the parser takes ownership of it.</summary>
    /// <param name="Item">The routine to add.</param>
    /// <returns>The index of the added routine.</returns>
    function AddFunction(Item: TCodeMethod): Integer;
    /// <summary>Reads a dotted name (<c>A.B.C</c>) from the current token on.</summary>
    /// <returns>The qualified name; '' if the current token is not an identifier.</returns>
    function ParseQualifiedName: string;
    /// <summary>
    /// Creates the preprocessor and reads the module heading: its kind and name, the INTERFACE keyword, the first uses
    /// clause and, for a package, the REQUIRES and CONTAINS clauses.  A preprocessor error sets <see cref="ParseError"/>;
    /// on any error the preprocessor is freed, so later reads find no tokens.  Any exception other than
    /// EDelphiPreprocessor or EAbort is re-raised.
    /// </summary>
    procedure ParseHead;
  protected
    /// <summary>
    /// Defines the symbols the parsed source sees: the compiler's predefined symbols (PredefinedSymbols) for the IDE's own
    /// bitness, Win64 or Win32, since the project's target is not known.  Override to add more.
    /// </summary>
    /// <param name="Parser">The preprocessor that will run over the source.</param>
    procedure InitDefines(Parser: TDelphiPreprocessor); virtual;
  public
    /// <summary>Creates a parser for the given source; nothing is parsed until <see cref="Parse"/> or <see cref="ParseUsesOnly"/>.</summary>
    /// <param name="AFilename">The source's file name, used to locate include files and reported in token locations.</param>
    /// <param name="AText">The source text to parse.</param>
    constructor Create(const AFilename: string; const AText: UTF8String);
    /// <summary>Frees the parser and every result it holds (classes, routines, uses lists).</summary>
    destructor Destroy; override;

    /// <summary>Folders searched for an include file that is not found beside the file that includes it.</summary>
    property IncludeDirs: TStrings read FIncludeDirs;

    /// <summary>
    /// Parses the text that was given to the constructor and fills the properties below: module, uses clauses, resources,
    /// include files, classes and stand-alone routines.  Previous results are cleared first.  A preprocessor error sets
    /// <see cref="ParseError"/> and stops the parse without raising.
    /// </summary>
    procedure Parse;
    /// <summary>
    /// Parses only the heading and the interface and implementation uses clauses (and a package's REQUIRES / CONTAINS).
    /// Previous results are cleared first; a preprocessor error sets <see cref="ParseError"/> without raising.
    /// </summary>
    procedure ParseUsesOnly;

    /// <summary>
    /// True when the last <c>Parse</c> / <c>ParseUsesOnly</c> stopped on a preprocessor error (an
    /// unmatched <c>$ENDIF</c>, a malformed directive, ...).  The uses lists and locations are then
    /// partial, so a caller that edits the source from them must not trust them.
    /// </summary>
    property ParseError: Boolean read FParseError;

    /// <summary>Every class the parser found in this file (and its include files).</summary>
    property Classes: TCodeClassList read FClasses;

    /// <summary>The kind of module: mtUnit, mtProgram, mtLibrary or mtPackage.</summary>
    property ModuleType: TModuleType read FModuleType;
    /// <summary>The module's name as read from the file content (the UNIT, PROGRAM, LIBRARY or PACKAGE name).</summary>
    property ModuleName: string read FModuleName;
    /// <summary>
    /// The form resource (<c>*.dfm</c>, <c>*.fmx</c>, <c>*.nfm</c>, <c>*.xfm</c> or <c>*.lfm</c>) if the file includes
    /// one with $R; otherwise ''.
    /// </summary>
    property FormResource: string read FFormResource;

    /// <summary>The number of resources included with $R.</summary>
    property ResourceCount: Integer read GetResourceCount;
    /// <summary>The resource file names (or <c>*.xxx</c>) included with $R.  The FormResource is also in this list.</summary>
    /// <param name="Index">The 0-based resource index.</param>
    property Resources[Index: Integer]: string read GetResource;

    /// <summary>The number of files included with $I / $INCLUDE.</summary>
    property IncludeFileCount: Integer read GetIncludeFileCount;
    /// <summary>The names of the files included with $I / $INCLUDE, unquoted, as written in the directive.</summary>
    /// <param name="Index">The 0-based include-file index.</param>
    property IncludeFiles[Index: Integer]: string read GetIncludeFiles;

    /// <summary>
    /// Every unit name (and filename, if given) of the first USES clause: the interface uses of a unit, or the uses of a
    /// program or library.
    /// </summary>
    property InterfaceUses: TUsesList read FInterfaceUses;
    /// <summary>Every unit name (and filename, if given) of the implementation USES clause (unit only).</summary>
    property ImplUses: TUsesList read FImplUses;
    /// <summary>Every required package of the REQUIRES clause (package only).</summary>
    property Requires: TUsesList read FRequires;
    /// <summary>Every contained unit name (and filename, if given) of the CONTAINS clause (package only).</summary>
    property Contains: TUsesList read FContains;

    /// <summary>Finds a stand-alone routine of the implementation section by name, ignoring case.</summary>
    /// <param name="AName">The routine's name.</param>
    /// <returns>The first matching routine, or nil if none was found.</returns>
    function FindFunction(const AName: string): TCodeMethod;
    /// <summary>The number of stand-alone routines found in the implementation section.</summary>
    property FunctionCount: Integer read GetFunctionCount;
    /// <summary>The stand-alone (non-method) routines found in the implementation section.</summary>
    /// <param name="Index">The 0-based routine index.</param>
    property Functions[Index: Integer]: TCodeMethod read GetFunctionItem;

    /// <summary>The location of the INTERFACE keyword; EmptyLocation if there is none.</summary>
    property InterfaceLocation: TLocation read FInterfaceLocation;
    /// <summary>The location of the IMPLEMENTATION keyword; EmptyLocation if there is none.</summary>
    property ImplLocation: TLocation read FImplLocation;

    /// <summary>The name of the file to parse, as given to the constructor.</summary>
    property Filename: string read FFilename;
    /// <summary>The text to parse, as given to the constructor.</summary>
    property Text: UTF8String read FText;
  end;

const
  /// <summary>Sentinel TLocation value used to indicate "no location".</summary>
  EmptyLocation: TLocation = (Line: 0; Column: 0; Filename: '');

implementation

uses
  System.StrUtils;

const
  ClassAvailableTokens = [tkIdent..tkIdentStrictReserved] -
    [tkI_public, tkI_private, tkI_protected, tkI_strict, tkI_published,
     tkI_end, tkI_class, tkI_var,  tkI_const, tkI_out, tkI_property,
     tkI_implementation];

  SectionEndTokens = [tkIdentStrictReserved..tkLast];
  ClassSectionEndTokens = SectionEndTokens + [tkI_strict];
  ArgModifierTokens = [tkI_var, tkI_out, tkI_const];

  PropertyTokens = [tkI_read, tkI_write, tkI_add, tkI_remove, tkI_stored, tkI_default];

function TokenToLocation(Token: TToken): TLocation;
begin
  Result.Line := Token.Line;
  Result.Column := Token.Column;
  Result.Filename := Token.Filename;
  Result.Index := Token.Index;
end;

{ TCodeSymbol }

constructor TCodeSymbol.Create(const AName: string; const ALocation: TLocation);
begin
  inherited Create;
  FName := AName;
  FLocation := ALocation;
  FAccess := akPublished;
end;

class function TCodeSymbol.FindSymbol(List: TObjectList; const AName: string): TCodeSymbol;
var
  i: Integer;
begin
  for i := 0 to List.Count - 1 do
  begin
    Result := TCodeSymbol(List[i]);
    if SameText(Result.Name, AName) then
      Exit;
  end;
  Result := nil;
end;

function TCodeSymbol.ToString: string;
begin
  Result := FName;
end;

{ TCodeField }

procedure TCodeField.SetTypeNameLater(const ATypeName: string);
begin
  FTypeName := ATypeName;
end;

function TCodeField.ToString: string;
begin
  Result := Name + ': ' + TypeName;
end;

{ TCodeProperty }

function TCodeProperty.ToString: string;
begin
  Result := Name;
  if IsArray then
    Result := Result + '[]';
  Result := Result + ': ' + TypeName;
  if Getter <> '' then
    Result := Result + ' read ' + Getter;
  if Adder <> '' then
    Result := Result + ' add ' + Adder;
  if Setter <> '' then
    Result := Result + ' write ' + Setter;
  if Remover <> '' then
    Result := Result + ' remove ' + Remover;
  if Storer <> '' then
    Result := Result + ' stored ' + Storer;
  if IsDefault then
    Result := Result + '; default'
  else
  if IsNoDefault then
    Result := Result + '; nodefault';
end;

{ TCodeMethodArg }

function TCodeMethodArg.ToString: string;
begin
  case Modifier of
    amVar: Result := 'var ';
    amOut: Result := 'out ';
    amConst: Result := 'const ';
  else
    Result := '';
  end;
  Result := Result + inherited ToString;
end;

{ TCodeMethod }

function TCodeMethod.AddArg(Item: TCodeMethodArg): Integer;
begin
  Result :=  FArgs.Add(Item);
end;

function TCodeMethod.AddLocalVariable(Item: TCodeLocalVariable): Integer;
begin
  Result := FLocalVariables.Add(Item);
end;

function TCodeMethod.AddLocalProc(Item: TCodeMethod): Integer;
begin
  Result := FLocalProcs.Add(Item);
end;

constructor TCodeMethod.Create(const AName: string; const ALocation: TLocation);
begin
  inherited Create(AName, ALocation);
  FArgs := TObjectList.Create;
  FLocalVariables := TObjectList.Create;
  FLocalProcs := TObjectList.Create;
end;

destructor TCodeMethod.Destroy;
begin
  FLocalProcs.Free;
  FLocalVariables.Free;
  FArgs.Free;
  inherited Destroy;
end;

function TCodeMethod.IsCompatible(M: TCodeMethod): Boolean;
var
  i: Integer;
begin
  if M = Self then
    Result := True
  else if M = nil then
    Result := False
  else
  begin
    Result := (MethodType = M.MethodType) and (Convention = M.Convention) and
        (IsClassMethod = M.IsClassMethod) and (IsClassStatic = M.IsClassStatic) and
        (ArgCount = M.ArgCount) and (ReturnTypeName = M.ReturnTypeName);

    if Result then
    begin
      for i := 0 to ArgCount - 1 do
      begin
        Result := (Args[i].Modifier = M.Args[i].Modifier) and
                  (Args[i].TypeName = M.Args[i].TypeName);
        if not Result then
          Exit;
      end;
    end;
  end;
end;

function TCodeMethod.FindArg(const AName: string): TCodeMethodArg;
begin
  Result := TCodeMethodArg(FindSymbol(FArgs, AName));
end;

function TCodeMethod.GetArg(Index: Integer): TCodeMethodArg;
begin
  Result := TCodeMethodArg(FArgs[Index]);
end;

function TCodeMethod.GetArgCount: Integer;
begin
  Result := FArgs.Count;
end;

function TCodeMethod.ToString: string;
var
  i: Integer;
begin
  case MethodType of
    mtConstructor: Result := 'constructor';
    mtDestructor: Result := 'destructor';
    mtFunction: Result := 'function';
    mtProcedure: Result := 'procedure';
  end;
  Result := Result + ' ' + Name + '(';
  for i := 0 to ArgCount - 1 do
  begin
    Result := Result + Args[i].ToString;
    if i < ArgCount - 1 then
      Result := Result + '; ';
  end;
  Result := Result + ')';
  if ReturnTypeName <> '' then
    Result := Result + ': ' + ReturnTypeName;
end;

function TCodeMethod.GetLocalVariableCount: Integer;
begin
  Result := FLocalVariables.Count;
end;

function TCodeMethod.GetLocalVariable(Index: Integer): TCodeLocalVariable;
begin
  Result := TCodeLocalVariable(FLocalVariables[Index]);
end;

function TCodeMethod.GetLocalProcCount: Integer;
begin
  Result := FLocalProcs.Count;
end;

function TCodeMethod.GetLocalProc(Index: Integer): TCodeMethod;
begin
  Result := TCodeMethod(FLocalProcs[Index]);
end;

{ TCodeClass }

constructor TCodeClass.Create(const AName: string; const ALocation: TLocation);
begin
  inherited Create(AName, ALocation);
  FInterfaces := TStringList.Create;
  FFields := TObjectList.Create;
  FProperties := TObjectList.Create;
  FMethods := TObjectList.Create;
end;

destructor TCodeClass.Destroy;
begin
  FInterfaces.Free;
  FFields.Free;
  FProperties.Free;
  FMethods.Free;
  inherited Destroy;
end;

function TCodeClass.GetInterfaceItem(Index: Integer): string;
begin
  Result := FInterfaces[Index];
end;

function TCodeClass.GetInterfaceCount: Integer;
begin
  Result := FInterfaces.Count;
end;

function TCodeClass.GetAccessInsert(Access: TAccessKind): TLocation;
begin
  Result := FAccessInsert[Access];
end;

function TCodeClass.GetPropertyCount: Integer;
begin
  Result := FProperties.Count;
end;

function TCodeClass.GetMethodCount: Integer;
begin
  Result := FMethods.Count;
end;

function TCodeClass.GetFieldCount: Integer;
begin
  Result := FFields.Count;
end;

function TCodeClass.GetProperty(Index: Integer): TCodeProperty;
begin
  Result := TCodeProperty(FProperties[Index]);
end;

function TCodeClass.GetMethodItem(Index: Integer): TCodeMethod;
begin
  Result := TCodeMethod(FMethods[Index]);
end;

function TCodeClass.GetField(Index: Integer): TCodeField;
begin
  Result := TCodeField(FFields[Index]);
end;

function TCodeClass.FindField(const AName: string): TCodeField;
begin
  Result := TCodeField(FindSymbol(FFields, AName));
end;

function TCodeClass.FindProperty(const AName: string): TCodeProperty;
begin
  Result := TCodeProperty(FindSymbol(FProperties, AName));
end;

function TCodeClass.FindMethod(const AName: string): TCodeMethod;
begin
  Result := TCodeMethod(FindSymbol(FMethods, AName));
end;

function TCodeClass.AddProperty(Item: TCodeProperty): Integer;
begin
  Result := FProperties.Add(Item);
end;

function TCodeClass.AddMethod(Item: TCodeMethod): Integer;
begin
  Result := FMethods.Add(Item);
end;

function TCodeClass.AddField(Item: TCodeField): Integer;
begin
  Result := FFields.Add(Item);
end;

function TCodeClass.AddInterface(const Item: string): Integer;
begin
  Result := FInterfaces.Add(Item);
end;

function TCodeClass.SupportsInterface(const AName: string): Boolean;
begin
  Result := FInterfaces.IndexOf(AName) >= 0;
end;

{ TCodeClassList }

constructor TCodeClassList.Create;
begin
  inherited Create;
  FItems := TObjectList.Create;
end;

destructor TCodeClassList.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TCodeClassList.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TCodeClassList.Find(const ClassName: string): TCodeClass;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
  begin
    Result := Items[i];
    if SameText(Result.Name, ClassName) then
      Exit;
  end;
  Result := nil;
end;

function TCodeClassList.Add(Item: TCodeClass): Integer;
begin
  Result := FItems.Add(Item);
end;

function TCodeClassList.GetItem(Index: Integer): TCodeClass;
begin
  Result := TCodeClass(FItems[Index]);
end;

procedure TCodeClassList.Clear;
begin
  FItems.Clear;
end;

{ TUsesItem }

constructor TUsesItem.Create(const AName, AFilename: string; const ALocation: TLocation);
begin
  inherited Create(AName,  ALocation);
  FName := AName;
  FFilename := AFilename;
  FLocation := ALocation;
end;

{ TUsesList }

constructor TUsesList.Create;
begin
  inherited Create;
  FItems := TObjectList.Create;
end;

destructor TUsesList.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TUsesList.AddUses(Item: TUsesItem): Integer;
begin
  Result := FItems.Add(Item);
end;

function TUsesList.FindUses(const AName: string): TUsesItem;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
  begin
    Result := Items[i];
    if SameText(Result.Name, AName) then
      Exit;
  end;
  Result := nil;
end;

function TUsesList.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TUsesList.GetItem(Index: Integer): TUsesItem;
begin
  Result := TUsesItem(FItems[Index]);
end;

function TUsesList.IndexOf(AItem: TUsesItem): Integer;
begin
  Result := FItems.IndexOf(AItem);
end;

procedure TUsesList.Clear;
begin
  FItems.Clear;
end;

{ TDesignerParser }

constructor TDesignerParser.Create(const AFilename: string; const AText: UTF8String);
begin
  inherited Create;
  FClasses := TCodeClassList.Create;
  FFilename := AFilename;
  FText := AText;
  FInterfaceUses := TUsesList.Create;
  FImplUses := TUsesList.Create;
  FResources := TStringList.Create;
  FIncludeFiles := TStringList.Create;
  FRequires := TUsesList.Create;
  FContains := TUsesList.Create;
  FFunctions := TObjectList.Create;
  FIncludeDirs := TStringList.Create;
end;

destructor TDesignerParser.Destroy;
begin
  FIncludeDirs.Free;
  FFunctions.Free;
  FInterfaceUses.Free;
  FImplUses.Free;
  FClasses.Free;
  FIncludeFiles.Free;
  FResources.Free;
  FRequires.Free;
  FContains.Free;
  inherited Destroy;
end;

procedure TDesignerParser.Clear;
begin
  FInterfaceUses.Clear;
  FImplUses.Clear;
  FResources.Clear;
  FIncludeFiles.Clear;
  FClasses.Clear;
  FModuleName := '';
  FModuleType := mtUnit;
  FFormResource := '';
  FImplLocation := EmptyLocation;
  FInterfaceLocation := EmptyLocation;
  FImplementation := False;
  FRepeatLastToken := False;
  FParseError := False;
  FRequires.Clear;
  FContains.Clear;
  FFunctions.Clear;
end;

function TDesignerParser.GetResource(Index: Integer): string;
begin
  Result := FResources[Index];
end;

function TDesignerParser.GetResourceCount: Integer;
begin
  Result := FResources.Count;
end;

function TDesignerParser.GetIncludeFiles(Index: Integer): string;
begin
  Result := FIncludeFiles[Index];
end;

function TDesignerParser.GetIncludeFileCount: Integer;
begin
  Result := FIncludeFiles.Count;
end;

function TDesignerParser.AddFunction(Item: TCodeMethod): Integer;
begin
  Result := FFunctions.Add(Item);
end;

function TDesignerParser.GetFunctionCount: Integer;
begin
  Result := FFunctions.Count;
end;

function TDesignerParser.GetFunctionItem(Index: Integer): TCodeMethod;
begin
  Result := TCodeMethod(FFunctions[Index]);
end;

function TDesignerParser.Look: TToken;
begin
  Result := p.CurrentToken;
end;

function TDesignerParser.Next: Boolean;
begin
  if p = nil then
    Exit(False); // the preprocessor was dropped after an error: nothing more to read
  if FRepeatLastToken then
  begin
    Result := p.CurrentToken <> nil;
    FRepeatLastToken := False;
  end
  else
    Result := p.GetToken <> nil;
end;

procedure TDesignerParser.NextA;
begin
  if not Next then
    Abort;
end;

procedure TDesignerParser.IncludeFile(Sender: TObject; const Name: string);
var
  LName: string;
begin
  LName := AnsiDequotedStr(Name, '''');
  FIncludeFiles.Add(LName);
  // An include that exists but cannot be read (locked, no access) leaves the parse incomplete: it is
  // reported through ParseError, never raised into the caller.
  try
    IncludeFoundFile(Sender as TDelphiPreprocessor, LName);
  except
    on E: EStreamError do
      FParseError := True;
    on E: EOSError do
      FParseError := True;
  end;
end;

procedure TDesignerParser.IncludeFoundFile(Preprocessor: TDelphiPreprocessor; const LName: string);
var
  Dir, FileName: string;
  I: Integer;
begin
  Dir := ExtractFileDir(Preprocessor.CurrentFileName);
  if (Length(LName) >= 2) and (LName[1] <> '\') and (LName[2] <> ':') then
  begin
    FileName := Dir + '\' + LName;
    if (Dir <> '') and FileExists(FileName) then
      Preprocessor.AddInclude(ExpandFileName(FileName), LoadTextFileToUtf8String(FileName))
    else
    begin
      for I := 0 to IncludeDirs.Count - 1 do
      begin
        FileName := ExcludeTrailingPathDelimiter(IncludeDirs[I]) + '\' + LName;
        if FileExists(FileName) then
        begin
          Preprocessor.AddInclude(ExpandFileName(FileName), LoadTextFileToUtf8String(FileName));
          Break;
        end;
      end;
    end;
  end;
end;

procedure TDesignerParser.InitDefines(Parser: TDelphiPreprocessor);
begin
  // The compiler's predefined symbols for the IDE's own bitness (the parser does not know the
  // project's target), shared with the Unreachable Code scanner.
  for var sSymbol in PredefinedSymbols({$IFDEF WIN64}'Win64'{$ELSE}'Win32'{$ENDIF}) do
    Parser.Define(sSymbol);
end;

procedure TDesignerParser.Directive(Sender: TObject; Token: TToken);
var
  Op: string;
begin
  Op := Token.Value;
  if Op[1] = '{' then
    Op := Trim(Copy(Op, 2, Length(Op) - 2))
  else
    Op := Trim(Copy(Op, 3, Length(Op) - 4));
  if StartsText('$R', Op) and (PChar(Op)[2] <= ' ') then
  begin
    // resource inclusion
    Op := AnsiDequotedStr(Trim(Copy(Op, 4, MaxInt)), '''');
    if EndsText('*.dfm', Op) or EndsText('*.fmx', Op) or
       EndsText('*.nfm', Op) or EndsText('*.xfm', Op) or
       EndsText('*.lfm', Op) then
      FFormResource := Op;
    FResources.Add(Op);
  end;
end;

procedure TDesignerParser.ParseHead;
begin
  p := TDelphiPreprocessor.Create(FFilename, FText);
  try
    InitDefines(p);

    p.OnIncludeFile := IncludeFile;
    p.OnDirective := Directive;
    p.OnGetDeclared := GetDeclared;
    p.OnGetConstValue := GetConstValue;
    p.OnGetConstBoolValue := GetConstBoolValue;

    FImplementation := False;

    // Without a module name the whole file will be ignored.
    // Find "program", "unit", "library", "package"
    while Next do
    begin
      case Look.Kind of
        tkI_Unit: FModuleType := mtUnit;
        tkI_Program: FModuleType := mtProgram;
        tkI_Library: FModuleType := mtLibrary;
        tkI_Package: FModuleType := mtPackage;
      end;

      case Look.Kind of
        tkI_Unit,
        tkI_Program,
        tkI_Library,
        tkI_Package:
          begin
            NextA;
            FModuleName := ParseQualifiedName;
            if Look.Kind = tkSemicolon then
              NextA;
            Break;
          end;
      end;
    end;
    if (Look <> nil) and (Look.Kind = tkI_interface) then
    begin
      FInterfaceLocation := TokenToLocation(Look);
      NextA;
    end;

    if (Look <> nil) and (Look.Kind = tkI_uses) then
    begin
      ParseUses(FInterfaceUses);
      if Look.Kind = tkSemicolon then
        Next;
    end;

    if ModuleType = mtPackage then
    begin
      while (Look <> nil) and (Look.Kind <> tkI_requires) do
        Next;
      if (Look <> nil) and (Look.Kind = tkI_requires) then
      begin
        ParseUses(FRequires);
        if Look.Kind = tkSemicolon then
          Next;
      end;

      while (Look <> nil) and (Look.Kind <> tkI_contains) do
        Next;
      if (Look <> nil) and (Look.Kind = tkI_contains) then
      begin
        ParseUses(FContains);
        if Look.Kind = tkSemicolon then
          Next;
      end;
    end;

    if (Look <> nil) and (Look.Kind <> tkSemicolon) then
      FRepeatLastToken := True;
  except
    // Only the parser's own stop signals are absorbed, and a preprocessor error is recorded, so a
    // caller can tell a complete parse from a truncated one.  Anything else (an AV) propagates.
    on E: EDelphiPreprocessor do
    begin
      FParseError := True;
      FreeAndNil(p);
    end;
    on E: EAbort do
      FreeAndNil(p);
    on E: Exception do
    begin
      FreeAndNil(p);
      raise;
    end;
  end;
end;

procedure TDesignerParser.ParseUsesOnly;
begin
  Clear;
  try
    ParseHead;
    try
      while Next do
      begin
        if Look.Kind = tkI_implementation then
        begin
          FImplLocation := TokenToLocation(Look);
          FImplementation := True;
          NextA;
          if Look.Kind = tkI_uses then
            ParseUses(FImplUses);
          Break;
        end;
      end;
    finally
      FreeAndNil(p);
    end;
  except
    on E: EDelphiPreprocessor do
      FParseError := True;
    on E: EAbort do
      ;
  end;
end;

procedure TDesignerParser.Parse;
begin
  Clear;
  try
    ParseHead;
    try
      // implementation
      while Next do
      begin
        case Look.Kind of
          tkI_class:
            if Next and ((Look.Kind = tkLParan) or not (Look.Kind in [tkI_of, tkI_helper, tkSemicolon])) then // "... class("
              if (p.TokenCount > 3) and (p.Tokens[p.TokenCount - 1 - 2].Kind = tkEqual) then
                ParseClass
              else
                FRepeatLastToken := True;
          tkI_function,
          tkI_procedure,
          tkI_constructor,
          tkI_destructor,
          tkI_operator:
            ParseFunctionImpl(nil);
          tkI_interface:
            IgnoreInterface;
          tkI_record,
          tkI_object:
            IgnoreRecord;

          tkI_implementation:
            begin
              FImplLocation := TokenToLocation(Look);
              FImplementation := True;
              NextA;
              if Look.Kind = tkI_uses then
                ParseUses(FImplUses);
            end;
        end;
      end;

    finally
      FreeAndNil(p);
    end;
  except
    on E: EDelphiPreprocessor do
      FParseError := True;
    on E: EAbort do
      ;
  end;
end;

procedure TDesignerParser.IgnoreRecord;
var
  OpenParan: Integer;
begin
  Next;
  if Look.Kind = tkLParan then
  begin
    OpenParan := 1;
    while Next and (OpenParan > 0) do
    begin
      if Look.Kind = tkLParan then
        Inc(OpenParan)
      else if Look.Kind = tkRParan then
        Dec(OpenParan);
    end;
  end;

  if Look.Kind = tkSemicolon then
    Exit; // prototype declaration

  repeat
    case Look.Kind of
      tkI_procedure,
      tkI_function,
      tkI_constructor,
      tkI_destructor,
      tkI_operator:
        IgnoreProc;

      tkI_interface,
      tkI_record,
      tkI_object: // does the developer know what he does?
        IgnoreRecord;

      tkI_reference:
        begin
          NextA;
          if Look.Kind = tkI_to then
          begin
            NextA;
            IgnoreProc;
          end;
        end;

      tkI_class:
        begin
          NextA;
          case Look.Kind of
            tkI_procedure,
            tkI_function,
            tkI_constructor,
            tkI_destructor,
            tkI_operator:
              IgnoreProc;
          else
            FRepeatLastToken := True;
            IgnoreRecord;
          end;
        end;

      tkI_end:
        Break;
    end;
  until not Next;
end;

procedure TDesignerParser.IgnoreProc;
var
  Empty: Boolean;
begin
  if not Next then
    Exit;

  if Look.Kind >= tkIdent then
    if not Next then
      Exit;
  if Look.Kind = tkLParan then
    ParseFunctionArgs(nil);

  if Look.Kind = tkColon then
  begin
    NextA;
    ParseTypeName([]);
  end;

  if Look.Kind <> tkSemicolon then
    NextA;

  while Next do
  begin
    case Look.Kind of
      tkI_implementation,
      tkI_public,
      tkI_private,
      tkI_strict,
      tkI_protected,
      tkI_published,
      tkI_property,
      tkI_class:
        begin
          FRepeatLastToken := True;
          Break;
        end;

      tkI_function,
      tkI_procedure,
      tkI_constructor,
      tkI_destructor,
      tkI_operator,
      tkI_type,
      tkI_var,
      tkI_const,
      tkI_threadvar,
      tkI_end:
        if not FImplementation then
        begin
          FRepeatLastToken := True;
          Break;
        end;

      tkI_begin:
        IgnoreBlock(Empty);
    end;
  end;
end;

function TDesignerParser.IgnoreBlock(out Empty: Boolean): TLocation;
var
  BlockCount: Integer;
begin
  Empty := True;
  if Look.Kind = tkI_begin then
  begin
    NextA;
    FRepeatLastToken := True;
  end;
  Result := TokenToLocation(Look);
  BlockCount := 1;
  while Next do
  begin
    case Look.Kind of
      tkI_end:
        begin
          Dec(BlockCount);
          if BlockCount = 0 then
            Break;
        end;
      tkI_case,
      tkI_try,
      tkI_begin:
        begin
          Inc(BlockCount);
          Empty := False;
        end;
      tkI_procedure,
      tkI_function: // anonymous method
        begin
          IgnoreProc;
          Empty := False;
        end;
    else
      Empty := False;
    end;
  end;
end;

procedure TDesignerParser.IgnoreToClassAccess;
begin
  while Next do
  begin
    case Look.Kind of
      tkI_private,
      tkI_protected,
      tkI_public,
      tkI_published,
      tkI_strict,
      tkI_end:
        Exit;
    end;
  end;
  NextA; // abort
end;

procedure TDesignerParser.IgnoreExternal;
begin
  while Next do
  begin
    case Look.Kind of
      tkI_name,
      tkI_index,
      tkString,
      tkIdent,
      tkPlus:
        ;
    else
      FRepeatLastToken := True;
      Break;
    end;
  end;
end;

function TDesignerParser.ParseQualifiedName: string;
begin
  Result := '';
  repeat
    if Look.Kind >= tkIdent then
      Result := Result + Look.Value
    else
      Break;
    NextA;
    if Look.Kind <> tkDot then
      Break;
    Result := Result + '.';
    NextA;
  until False;
end;

procedure TDesignerParser.ParseClass;
var
  NameToken: TToken;
  C: TCodeClass;
  Access, NewAccess: TAccessKind;
  IntfName: string;
begin
  try
    NameToken := p.Tokens[p.TokenCount - 1 - 3];
    if NameToken.Kind = tkIdent then
    begin
      C := TCodeClass.Create(NameToken.Value, TokenToLocation(NameToken));
      Classes.Add(C);
      C.FStartLocation := C.Location;
      C.FIsUnitPrivate := FImplementation;

      if Look.Kind = tkLParan then
      begin
        NextA;
        C.FBaseClass := ParseQualifiedName;
        while Look.Kind = tkComma do
        begin
          NextA;
          IntfName := ParseQualifiedName;
          if IntfName <> '' then
            C.AddInterface(IntfName);
          NextA;
        end;
        if Look.Kind = tkRParan then
          NextA;
      end
      else
        C.FBaseClass := 'TObject';

      if Look.Kind <> tkSemicolon then
      begin
        FRepeatLastToken := True;
        Access := akPublished;
        NewAccess := Access;

        while Next do
        begin
          case Look.Kind of
            tkI_class:
              begin
                NextA;
                case Look.Kind of
                  tkI_procedure,
                  tkI_function,
                  tkI_constructor,
                  tkI_destructor,
                  tkI_operator:
                    ParseMethodDecl(C, Access, True);
                  tkI_property:
                    ParseProperty(C, Access, True);
                  tkIdent..Pred(tkIdentStrictReserved):
                    ParseField(C, Access, True);
                end;
              end;

            tkI_procedure,
            tkI_function,
            tkI_constructor,
            tkI_destructor,
            tkI_operator:
              ParseMethodDecl(C, Access, False);
            tkI_property:
              ParseProperty(C, Access, False);

            tkIdent..Pred(tkIdentStrictReserved):
              begin
                case Look.Kind of
                  tkI_strict:
                    begin
                      NextA;
                      case Look.Kind of
                        tkI_private:
                          NewAccess := akStrictPrivate;
                        tkI_protected:
                          NewAccess := akStrictProtected;
                      end;
                    end;
                  tkI_private:
                    NewAccess := akPrivate;
                  tkI_protected:
                    NewAccess := akProtected;
                  tkI_public:
                    NewAccess := akPublic;
                  tkI_published:
                    NewAccess := akPublished;
                else
                  ParseField(C, Access, False);
                end;
              end;

            tkI_type,
            tkI_const:
              begin
                // inner classes/constants (Delphi 8+)
                IgnoreToClassAccess;
              end;

            tkI_implementation,
            tkI_begin:
              begin
                FRepeatLastToken := True;
                Break;
              end;
            tkI_end:
              begin
                C.FEndLocation := TokenToLocation(Look);
                Break;
              end;
          end;

          if NewAccess <> Access then
          begin
            if C.FAccessInsert[Access].Filename = '' then
              C.FAccessInsert[Access] := TokenToLocation(Look);
            Access := NewAccess;
          end;
        end;
      end;
    end
    else
      IgnoreRecord;
  except
    on E: EAbort do
      IgnoreRecord;
  end;
end;

procedure TDesignerParser.ParseField(C: TCodeClass; Access: TAccessKind; IsClass: Boolean);
var
  StartIndex, i: Integer;
  F: TCodeField;
begin
  FRepeatLastToken := True; // current token is already the NameToken
  StartIndex := C.FFields.Count;
  ParseVariableList(C.FFields, vmFields);
  for i := StartIndex to C.FFields.Count - 1 do
  begin
    F := C.Fields[i];
    F.FIsClassField := IsClass;
    F.FAccess := Access;
  end;
  if Look.Kind <> tkSemicolon then
    FRepeatLastToken := True;
end;

procedure TDesignerParser.ParseProperty(C: TCodeClass; Access: TAccessKind; IsClass: Boolean);
var
  P: TCodeProperty;
  PropToken, NameToken: TToken;
  IsArray: Boolean;
  IsInheritChange: Boolean;
begin
  PropToken := Look;
  NextA;
  NameToken := Look;
  NextA;

  IsArray := False;
  if Look.Kind = tkLBracket then
  begin
    // array
    NextA;
    IsArray := True;
    while Next and not (Look.Kind in [tkRBracket] + PropertyTokens + ClassSectionEndTokens) do
      ;
  end;

  IsInheritChange := Look.Kind <> tkColon;
  if not IsInheritChange then
    NextA;

  P := TCodeProperty.Create(NameToken.Value, TokenToLocation(NameToken));
  C.AddProperty(P);
  P.FStartLocation := TokenToLocation(PropToken);
  P.FIsClassProperty := IsClass;
  P.FAccess := Access;
  P.FIsArray := IsArray;
  P.FIsInheritChange := IsInheritChange;
  if not IsInheritChange then
    P.FTypeName := ParseTypeName(PropertyTokens + ClassSectionEndTokens);

  if Look.Kind = tkI_read then
  begin
    NextA;
    if Look.Kind >= tkIdent then
      P.FGetter := Look.Value;
    NextA;
  end;
  if Look.Kind = tkI_write then
  begin
    NextA;
    if Look.Kind >= tkIdent then
      P.FSetter := Look.Value;
    NextA;
  end;
  if Look.Kind = tkI_add then
  begin
    NextA;
    if Look.Kind >= tkIdent then
      P.FAdder := Look.Value;
    NextA;
  end;
  if Look.Kind = tkI_remove then
  begin
    NextA;
    if Look.Kind >= tkIdent then
      P.FRemover := Look.Value;
    NextA;
  end;
  if Look.Kind = tkI_read then
  begin
    NextA;
    if Look.Kind >= tkIdent then
      P.FGetter := Look.Value;
    NextA;
  end;
  if Look.Kind = tkI_stored then
  begin
    NextA;
    if Look.Kind >= tkIdent then
      P.FStorer := Look.Value;
    NextA;
  end;
  if Look.Kind = tkI_default then
  begin
    NextA;
    while not (Look.Kind in [tkSemicolon] + ClassSectionEndTokens) do
      NextA;
  end;

  if Look.Kind = tkSemicolon then
  begin
    NextA;
    case Look.Kind of
      tkI_default:
        begin
          P.FIsDefault := True;
          NextA;
        end;
      tkI_nodefault:
        begin
          P.FIsNoDefault := True;
          NextA;
        end;
    else
      FRepeatLastToken := True;
    end;
  end;
  P.FEndLocation := TokenToLocation(Look);
end;

function TDesignerParser.ParseTypeName(const Stop: TTokenKindSet): string;
begin
  Result := Look.Value;
  case Look.Kind of
    tkI_array:
      begin
        NextA;
        Result := 'array';
        if Look.Kind = tkLBracket then
        begin
          Result := 'array[';
          while Next and (Look.Kind <> tkRBracket) do
            if Result[Length(Result)] = ',' then
              Result := Result + ' ' + Look.Value
            else
              Result := Result + Look.Value;
          Result := Result + ']';
          NextA;
        end;
        if Look.Kind = tkI_of then
        begin
          NextA;
          Result := Result + ' of ' + ParseTypeName(Stop);
        end
        else
        begin
          FRepeatLastToken := True;
          Result := Result + ' of errornous';
        end;
      end;
    tkI_set:
      begin
        NextA;
        if Look.Kind = tkI_of then
        begin
          NextA;
          Result := 'set of ';
          if Look.Kind = tkLBracket then
          begin
            Result := Result + '[';
            while Next and (Look.Kind <> tkRBracket) do
              if Result[Length(Result)] = ',' then
                Result := Result + ' ' + Look.Value
              else
                Result := Result + Look.Value;
            Result := Result + ']';
          end
          else if Look.Kind in ClassAvailableTokens then
            Result := Result + Look.Value
          else
          begin
            FRepeatLastToken := True;
            Result := Result + 'errornous';
          end;
        end;
      end;

    tkI_record,
    tkI_object:
      IgnoreRecord;

    tkI_function,
    tkI_procedure:
      IgnoreProc;

  else
    if not (Look.Kind in ClassAvailableTokens) and (Look.Kind <> tkI_string) then
    begin
      Result := 'errornous';
      FRepeatLastToken := True;
    end
    else if Look.Kind = tkI_reference then
    begin
      NextA;
      if Look.Kind = tkI_to then
      begin
        NextA;
        IgnoreProc;
      end;
    end

    else if Look.Kind >= tkIdent then
      Result := ParseQualifiedName;
  end;
end;

procedure TDesignerParser.ParseFunctionArgs(M: TCodeMethod);
begin
  if M = nil then
    ParseVariableList(nil, vmFunctionArguments)
  else
    ParseVariableList(M.FArgs, vmFunctionArguments);
end;

procedure TDesignerParser.ParseVariableList(List: TObjectList; Mode: TVarListMode);
var
  A: TCodeField;
  ArgModifier: TArgModifier;
  StartIndex: Integer;
  NameToken: TToken;
  TypeName: string;
begin
  ArgModifier := amNone;
  StartIndex := 0;
  if List <> nil then
    StartIndex := List.Count;
  while Next do
  begin
    if Mode = vmFunctionArguments then
    begin
      ArgModifier := amNone;
      case Look.Kind of
        tkI_const:
          ArgModifier := amConst;
        tkI_var:
          ArgModifier := amVar;
        tkI_out:
          ArgModifier := amOut;
      end;
      if ArgModifier <> amNone then
        NextA;
    end;

    A := nil;
    if Look.Kind >= tkIdent then
    begin
      NameToken := Look;
      NextA;
      if List <> nil then
      begin
        if Mode = vmFunctionArguments then
        begin
          A := TCodeMethodArg.Create(NameToken.Value, TokenToLocation(NameToken));
          TCodeMethodArg(A).FModifier := ArgModifier;
        end
        else
          A := TCodeField.Create(NameToken.Value, TokenToLocation(NameToken));
        A.FStartLocation := A.Location;
        List.Add(A);
      end;
    end;

    case Look.Kind of
      tkColon:
        begin
          NextA;
          TypeName := ParseTypeName([tkRParan, tkComma]);
          if Look.Kind = tkSemicolon then
          begin
            if A <> nil then
              A.FEndLocation := TokenToLocation(Look);
            NextA;
            FRepeatLastToken := True;
          end
          else
          if A <> nil then
            A.FEndLocation := TokenToLocation(Look);

          if List <> nil then
          begin
            while StartIndex < List.Count do
            begin
              TCodeField(List[StartIndex]).SetTypeNameLater(TypeName);
              Inc(StartIndex);
            end;
          end;
        end;
      tkComma:
        begin
          if A <> nil then
            A.FEndLocation := TokenToLocation(Look);
          Continue;
        end;
    end;

    case Mode of
      vmFunctionArguments:
        if Look.Kind in [tkRParan] + SectionEndTokens - ArgModifierTokens then
        begin
          NextA;
          Break;
        end;
      vmVariables:
        if Look.Kind in SectionEndTokens then
        begin
          //FRepeatLastToken := True;
          Break;
        end;
      vmFields:
        if Look.Kind in ClassSectionEndTokens then
        begin
          //FRepeatLastToken := True;
          Break;
        end;
    end;
  end;
end;

procedure TDesignerParser.ParseMethodDecl(C: TCodeClass; Access: TAccessKind; IsClass: Boolean);
var
  M: TCodeMethod;
  MethodType: TMethodType;
  NameToken: TToken;
  StartToken: TToken;
begin
  StartToken := Look;
  if IsClass then
    StartToken := p.Tokens[p.TokenCount - 1 - 1];
  MethodType := mtFunction;
  case Look.Kind of
    tkI_constructor: MethodType := mtConstructor;
    tkI_destructor: MethodType := mtDestructor;
    tkI_function: MethodType := mtFunction;
    tkI_procedure: MethodType := mtProcedure;
  end;
  NextA;
  if Look.Kind < tkIdent then
  begin
    IgnoreProc;
    Exit;
  end;
  NameToken := Look;
  NextA;

  M := TCodeMethod.Create(NameToken.Value, TokenToLocation(NameToken));
  C.AddMethod(M);
  M.FStartLocation := TokenToLocation(StartToken);
  M.FIsDeclared := True;
  M.FAccess := Access;
  M.FIsClassMethod := IsClass;
  M.FMethodType := MethodType;
  if Look.Kind = tkLParan then
    ParseFunctionArgs(M);
  if Look.Kind = tkColon then
  begin
    NextA;
    M.FReturnTypeName := ParseTypeName([tkI_cdecl, tkI_stdcall, tkI_register,
      tkI_safecall, tkI_pascal, tkI_overload,
      tkI_reintroduce, tkI_virtual, tkI_override, tkI_abstract, tkI_message, tkI_dynamic,
      tkI_forward, tkI_export, tkI_external]);
  end;

  ParseDirectives(M);
  if Look.Kind = tkSemicolon then
  begin
    NextA;
    FRepeatLastToken := True;
  end;
  M.FEndLocation := TokenToLocation(Look);
end;

procedure TDesignerParser.ParseUses(List: TUsesList);
var
  StartToken, NameToken: TToken;
  Name, Filename: string;
  Item: TUsesItem;
begin
  List.FLocation := TokenToLocation(Look);
  while Next do
  begin
    if Look.Kind in SectionEndTokens then
    begin
      FRepeatLastToken := True;
      Break;
    end;
    if Look.Kind >= tkIdent then
    begin
      StartToken := Look;
      NameToken := StartToken;
      Name := ParseQualifiedName;
      Filename := '';
      if Look.Kind = tkI_in then
      begin
        NextA;
        if Look.Kind = tkString then
          Filename := AnsiDequotedStr(Look.Value, '''');
        if Look.Kind = tkSemicolon then
          Break;
        NextA;
      end;

      Item := TUsesItem.Create(Name, Filename, TokenToLocation(NameToken));
      List.AddUses(Item);
      Item.FStartLocation := TokenToLocation(StartToken);
      Item.FEndLocation := TokenToLocation(Look);
    end;
    if Look.Kind = tkSemicolon then
    begin
      List.FEndLocation := TokenToLocation(Look);
      FRepeatLastToken := True;
      Break;
    end;
  end;
end;

procedure TDesignerParser.ParseFunctionImpl(AParent: TCodeMethod);
var
  M, MatchM: TCodeMethod;
  MethodType: TMethodType;
  StartToken, NameToken: TToken;
  MethodClass: TCodeClass;
  i: Integer;
  IsClass, Empty: Boolean;
begin
  FRepeatLastToken := False;

  IsClass := (p.TokenCount > 1) and (p.Tokens[p.TokenCount - 1 - 1].Kind = tkI_class);
  StartToken := Look;
  if IsClass then
    StartToken := p.Tokens[p.TokenCount - 1 - 1];
  if (p.TokenCount > 2) then
    if p.Tokens[p.TokenCount - 2].Kind in [tkColon, tkEqual] then // ignore function variables/types
    begin
      IgnoreFunctionType;
      Exit;
    end;

  MethodType := mtFunction;
  case Look.Kind of
    tkI_constructor: MethodType := mtConstructor;
    tkI_destructor: MethodType := mtDestructor;
    tkI_function: MethodType := mtFunction;
    tkI_procedure: MethodType := mtProcedure;
  end;
  NextA;
  if Look.Kind < tkIdent then
  begin
    IgnoreProc;
    Exit;
  end;
  NameToken := Look;
  NextA;

  MethodClass := nil;
  while Look.Kind = tkDot do
  begin
    MethodClass := Classes.Find(NameToken.Value);
    if MethodClass = nil then
    begin
      IgnoreProc;
      Exit;
    end;
    NextA;
    NameToken := Look;
    if NameToken.Kind < tkIdent then
    begin
      IgnoreProc;
      Exit;
    end;
    NextA;
  end;
  M := TCodeMethod.Create(NameToken.Value, EmptyLocation);
  try
    M.FIsImplemented := True;
    M.FImplLocation := TokenToLocation(NameToken);
    M.FIsClassMethod := IsClass;
    M.FMethodType := MethodType;

    if Look.Kind = tkLParan then
      ParseFunctionArgs(M);
    if Look.Kind = tkColon then
    begin
      NextA;
      M.FReturnTypeName := ParseTypeName([tkI_Cdecl, tkI_Stdcall, tkI_Register,
        tkI_Safecall, tkI_Pascal, tkI_external, tkI_export, tkI_forward]);
    end
    else if Look.Kind = tkI_of then
    begin
      NextA;
      if Look.Kind = tkI_object then
        NextA;
    end;

    MatchM := nil;
    if MethodClass <> nil then
    begin
      // find a matching method
      for i := 0 to MethodClass.MethodCount - 1 do
      begin
        if SameText(MethodClass.Methods[i].Name, M.Name) and
           MethodClass.Methods[i].IsCompatible(M) then
        begin
          MatchM := MethodClass.Methods[i];
          Break;
        end;
      end;
      if (MatchM = nil) and (M.ArgCount = 0) and (M.ReturnTypeName = '') then
        MatchM := MethodClass.FindMethod(M.Name);
    end
    else
    begin
      // find a matching method
      for i := 0 to FunctionCount - 1 do
      begin
        if SameText(Functions[i].Name, M.Name) and
           Functions[i].IsCompatible(M) then
        begin
          MatchM := Functions[i];
          Break;
        end;
      end;
      {if (MatchM = nil) and (M.ArgCount = 0) and (M.ReturnTypeName = '') then
        MatchM := MethodClass.FindMethod(M.Name);}
    end;

    if MatchM <> nil then
    begin
      MatchM.FImplLocation := M.ImplLocation;
      MatchM.FIsImplemented := True;
    end
    else
    begin
      if AParent <> nil then
      begin
        M.FIsImplemented := True;
        AParent.AddLocalProc(M);
      end
      else if MethodClass = nil then
      begin
        M.FIsImplemented := True;
        if FImplementation then
          AddFunction(M);
      end
      else
        MethodClass.AddMethod(M);
      MatchM := M;
      if (MethodClass <> nil) or FImplementation then
        M := nil;
    end;

    if (MethodClass <> nil) and (M <> nil) then
      ParseDirectives(M) // here M not MatchM
    else
      ParseDirectives(MatchM);

    if Look.Kind = tkI_forward then
      NextA
    else if FImplementation then
    begin
      MatchM.FIsImplEmpty := True;
      while (Look <> nil) and (Look.Kind <> tkI_begin) do
      begin
        MatchM.FIsImplEmpty := False;
        case Look.Kind of
          tkI_record,
          tkI_object,
          tkI_class:
            IgnoreRecord;

          tkI_procedure,
          tkI_function:
            ParseFunctionImpl(MatchM);

          tkI_forward,
          tkI_end:
            Break;

          tkI_var:
            begin
              MatchM.FVarInsert := TokenToLocation(Look);
              NextA;
              ParseVariableDecl(MatchM.FLocalVariables);
            end;
        end;
        NextA;
      end;
    end;

    if (Look <> nil) and (Look.Kind = tkI_begin) then
      MatchM.FCodeInsert := IgnoreBlock(Empty);
    MatchM.FIsImplEmpty := MatchM.FIsImplEmpty and Empty;

    if Look.Kind = tkSemicolon then
    begin
      NextA;
      FRepeatLastToken := True;
    end;
    if FImplementation and (Look.Kind = tkI_end) then
    begin
      NextA;
      if Look.Kind = tkI_end then
        NextA;
      FRepeatLastToken := True;
    end;

    MatchM.FImplBeginLocation := TokenToLocation(StartToken);
    MatchM.FImplEndLocation := TokenToLocation(Look);
  finally
    M.Free;
  end;
end;

procedure TDesignerParser.ParseDirectives(M: TCodeMethod);
begin
  repeat
    case Look.Kind of
      tkSemicolon:
        ;
      tkI_Overload:
        ;

      tkI_static:
        M.FIsClassStatic := True;
      tkI_message:
        M.FVirtualKind := vkMessage;
      tkI_override:
        M.FVirtualKind := vkOverride;
      tkI_virtual:
        M.FVirtualKind := vkVirtual;
      tkI_abstract:
        M.FVirtualKind := vkAbstract;
      tkI_dynamic:
        M.FVirtualKind := vkDynamic;

      tkI_cdecl:
        M.FConvention := ccCdecl;
      tkI_stdcall:
        M.FConvention := ccStdcall;
      tkI_register:
        M.FConvention := ccRegister;
      tkI_safecall:
        M.FConvention := ccSafecall;
      tkI_pascal:
        M.FConvention := ccPascal;
      tkI_reintroduce:
        ;

      tkI_assembler:
        ;

      tkI_external:
        IgnoreExternal;

      {tkI_begin,
      tkI_end:
        Break;}

    else
      FRepeatLastToken := True;
      Break;
    end;
    NextA;
  until False;
end;

procedure TDesignerParser.IgnoreFunctionType;
var
  M: TCodeMethod;
begin
  Next; 
  if Look.Kind = tkLParan then
  begin
    M := TCodeMethod.Create('', TokenToLocation(Look));
    try
      ParseFunctionArgs(M);
    finally
      M.Free;
    end;
  end;
  if Look.Kind = tkColon then
  begin
    NextA;
    ParseTypeName([tkI_Cdecl, tkI_Stdcall, tkI_Register,
      tkI_Safecall, tkI_Pascal, tkI_external, tkI_export]);
  end;
  if Look.Kind = tkI_of then
  begin
    NextA;
    if Look.Kind = tkI_object then
      NextA;
  end;
  if Look.Kind = tkSemicolon then
  begin
    NextA;
    FRepeatLastToken := True;
  end;
end;

procedure TDesignerParser.IgnoreInterface;
begin
  IgnoreRecord;
end;

procedure TDesignerParser.GetDeclared(Sender: TObject; const Name: string;
  var Value: Boolean);
begin
  Value := InterfaceUses.FindUses(Name) <> nil;
  if not Value then
    Value := ImplUses.FindUses(Name) <> nil;
  if not Value then
    Value := Classes.Find(Name) <> nil;
  if not Value then
    Value := FindFunction(Name) <> nil;
end;

procedure TDesignerParser.GetConstValue(Sender: TObject; const Name: string; var Kind: TTokenKind;
  var Value: string);
var
  S: ShortString;
begin
  if SameText(Name, 'CompilerVersion') then
  begin
    Kind := tkFloat;
    Str(CompilerVersion:1:1, S);
    Value := UTF8ToString(S);
  end;
end;

procedure TDesignerParser.GetConstBoolValue(Sender: TObject; const Name: string; var Value: Boolean);
begin

end;

function TDesignerParser.FindFunction(const AName: string): TCodeMethod;
var
  i: Integer;
begin
  for i := 0 to FunctionCount - 1 do
    if SameText(Functions[i].Name, AName) then
    begin
      Result := Functions[i];
      Exit;
    end;
  Result := nil;
end;

procedure TDesignerParser.ParseVariableDecl(List: TObjectList);
begin
  ParseVariableList(List, vmVariables);
end;

end.
