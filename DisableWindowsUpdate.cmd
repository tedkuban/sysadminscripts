sc config "wuauserv" start= disabled
sc config "UsoSvc" start= disabled
net stop UsoSvc
net stop wuauserv
