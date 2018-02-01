{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit laz_visualplanit_design;

{$warn 5023 off : no warning about unused units}
interface

uses
  VpReg, VpPrtFmtEd, VpDatePropEdit, VpNabEd, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('VpReg', @VpReg.Register);
end;

initialization
  RegisterPackage('laz_visualplanit_design', @Register);
end.
