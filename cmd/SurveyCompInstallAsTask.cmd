@Echo Off
md %SYSTEMROOT%\happylook
copy /Y /V \\HAPPYLOOK\FS\SOFT\1C\SurveyComp.exe %SYSTEMROOT%\happylook\
copy /Y /V \\HAPPYLOOK\FS\SOFT\1C\SurveyComp.xml %SYSTEMROOT%\happylook\
rem SCHTASKS /Delete /TN "\SurveyComp" /F
SCHTASKS /Create /TN "\SurveyComp" /XML "C:\WINDOWS\HappyLook\SurveyComp.xml"
