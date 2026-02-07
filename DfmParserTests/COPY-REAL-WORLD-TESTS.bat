@echo off
REM Copy real-world DFM files from DBiWorkflow for testing
REM These are diverse examples covering different DFM features

echo Copying real-world DFM test files from DBiWorkflow...

REM Data module with SVG icon collection (multi-line string concatenation with #10)
copy "E:\DBiWorkflow Development\DBiAdmin\dmImages.dfm" TestData\RealWorld_DataModule.dfm

REM Login dialog with PageControl, TabSheets, GroupBox (typical dialog form)
copy "E:\DBiWorkflow Development\DBManager\logindlg.dfm" TestData\RealWorld_LoginDialog.dfm

REM Job status viewer (likely has TListView or similar with collections)
copy "E:\DBiWorkflow Development\DBiWorkflow\JTStatusViewFrm.dfm" TestData\RealWorld_StatusViewer.dfm

REM Print form (likely has report components)
copy "E:\DBiWorkflow Development\DBiStore\POPrintFrm.dfm" TestData\RealWorld_PrintForm.dfm

REM Simple backup dialog (smaller, less complex)
copy "E:\DBiWorkflow Development\DBManager\backupdlg.dfm" TestData\RealWorld_BackupDialog.dfm

echo.
echo Done! Real-world test files copied to TestData\
echo.
echo File sizes:
dir TestData\RealWorld_*.dfm

pause
