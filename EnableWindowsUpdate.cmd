sc config "wuauserv" start= demand
sc config "UsoSvc" start= demand
net start wuauserv
net start UsoSvc
