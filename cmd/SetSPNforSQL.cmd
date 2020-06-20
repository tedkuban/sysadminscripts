@Echo OFF
IF ## == #%1# GoTo Usage
setspn -D MSSQLSvc/%1.happylook.happylook.ru HAPPYLOOK\%1$
setspn -D MSSQLSvc/%1.happylook.happylook.ru:1433 HAPPYLOOK\%1$
setspn -U -S MSSQLSvc/%1.happylook.happylook.ru HAPPYLOOK\hlsqlserver
setspn -U -S MSSQLSvc/%1.happylook.happylook.ru:1433 HAPPYLOOK\hlsqlserver
GoTo END

:Usage
Usage: %~dp0 <computername>
:END