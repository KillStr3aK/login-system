#include <sourcemod>
#include <loginsystem>

#define PLUGIN_NEV	"Login system"
#define PLUGIN_LERIAS	"Ingame login system"
#define PLUGIN_AUTHOR	"Nexd"
#define PLUGIN_VERSION	"1.0.2"
#define PLUGIN_URL	"https://github.com/KillStr3aK"
#pragma tabsize 0

bool IsLoggedIn[MAXPLAYERS+1];
bool IsRegistered[MAXPLAYERS+1];
bool Register_U[MAXPLAYERS+1];
bool Register_P[MAXPLAYERS+1];
bool Login_U[MAXPLAYERS+1];
bool Login_P[MAXPLAYERS+1];

char Username[MAXPLAYERS+1][36];
char Password[MAXPLAYERS+1][32];
char lSettingsTableName[32];

Handle OnClientLoggedIn = INVALID_HANDLE;
Handle OnClientLoggedOut = INVALID_HANDLE;
Handle OnClientGotBanned = INVALID_HANDLE;

enum
{
	Min_Name,
	Min_Pass,
	OtherAcc,
	Tablename,
	Kickplayers,
	Kicktime,
	Settings
}

ConVar lSettings[Settings], g_adatbazis;
Database g_DB;

public Plugin myinfo = 
{
	name = PLUGIN_NEV,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_LERIAS,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	lSettings[Min_Name] = CreateConVar("ls_min_name", "6", "Minimum characters for username");
	lSettings[Min_Pass] = CreateConVar("ls_min_pass", "6", "Minimum characters for password");
	lSettings[OtherAcc] = CreateConVar("ls_enable_otheracc", "0", "0 - Login only to the registered account | 1 - Enable login to other accounts ( consider it twice before enabling it! )");
	lSettings[Tablename] = CreateConVar("ls_database_name", "login_system", "Database name for the login system");
	lSettings[Kickplayers] = CreateConVar("ls_kick_players", "0", "Kick players if they didn't logged in before the timelimit");
	lSettings[Kicktime] = CreateConVar("ls_kick_time", "120", "Kick players after if they didn't logged in ( In seconds )");
	g_adatbazis = CreateConVar("ls_database", "loginsystem", "Database for the plugin ( databases.cfg )");

	AddCommandListener(Block_JoinTeam, "jointeam");
	AddCommandListener(Block_Commands, "say");
	AddCommandListener(Block_Commands, "say_team");

	RegConsoleCmd("sm_logout", Command_Logout);
	RegAdminCmd("sm_lsban", Command_LSBan, ADMFLAG_ROOT);

	LoadTranslations("loginsystem.phrases");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("LS_IsLoggedIn", Native_IsLoggedIn);

	OnClientLoggedIn = CreateGlobalForward("LS_OnClientLoggedIn", ET_Ignore, Param_Cell);
	OnClientLoggedOut = CreateGlobalForward("LS_OnClientLoggedOut", ET_Ignore, Param_Cell);
	OnClientGotBanned = CreateGlobalForward("LS_OnClientGotBanned", ET_Ignore, Param_Cell);

	return APLRes_Success;
}

public void OnClientDisconnect(int client)
{
	Username[client] = empty;
	Password[client] = empty;

	Register_U[client] = false;
	Register_P[client] = false;
	Login_U[client] = false;
	Login_P[client] = false;
	IsLoggedIn[client] = false;
	IsRegistered[client] = false;
}

public Action Block_Commands(int client, const char[] command, int args)
{
	if (!IsLoggedIn[client])
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Block_JoinTeam(int client, const char[] command, int args)
{
	if(IsFakeClient(client))
		return Plugin_Continue;

	if (!IsLoggedIn[client])
	{
	    ChangeClientTeam(client, 1);
	    PrintToChat(client, "%s %T", PREFIX, "Not logged in", client);
	    return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	if(!(client < 0) && !(client > MaxClients) && !IsFakeClient(client))
	{
		char CheckForAccount[1024];
		char steamid[20];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		Format(CheckForAccount, sizeof(CheckForAccount), "SELECT username FROM %s WHERE steamid = '%s';", lSettingsTableName, steamid);
		SQL_TQuery(g_DB, CheckAccount, CheckForAccount, client);

		if(lSettings[Kickplayers].IntValue == 1)
			CreateTimer(lSettings[Kicktime].FloatValue, Kick, client, TIMER_FLAG_NO_MAPCHANGE);

		CreateTimer(1.0, CheckTeams, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		CheckIpAddress(client);
	}
}

public Action CheckTeams(Handle timer, int client)
{
	if(!IsClientInGame(client))
		return Plugin_Stop;

	if(IsClientLoggedIn(client))
		return Plugin_Stop;

	if(GetClientTeam(client) > 1)
		ChangeClientTeam(client, 1);

	return Plugin_Continue;
}

stock Action CheckIpAddress(int client)
{
	char CheckForAccount[256];
	char steamid[20];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	Format(CheckForAccount, sizeof(CheckForAccount), "SELECT ipaddress FROM %s WHERE steamid = '%s';", lSettingsTableName, steamid);
	SQL_TQuery(g_DB, CheckIpAddress_C, CheckForAccount, client);
}

public void CheckIpAddress_C(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	char playerip[32];
	while (SQL_FetchRow(hndl)) {
		SQL_FetchString(hndl, 0, playerip, sizeof(playerip));
	}

	char clientip[32];
	GetClientIP(client, clientip, sizeof(clientip));

	if(!StrEqual(playerip, clientip))
	{
		char steamid[20];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		char UpdateQuery[512];
		Format(UpdateQuery, sizeof(UpdateQuery), "UPDATE `%s` SET `ipaddress` = '%s' WHERE `%s`.`steamid` = '%s';", lSettingsTableName, clientip, steamid);
		SQL_TQuery(g_DB, SQLHibaKereso, UpdateQuery);
	}
}

public Action Kick(Handle timer, int client)
{
	if(IsClientInGame(client) && !IsLoggedIn[client])
		KickClient(client, "%T", "Kick message", client);
}

public void CheckAccount(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	char username[32];
	while (SQL_FetchRow(hndl)) {
		SQL_FetchString(hndl, 0, username, sizeof(username));
	}

	if(StrEqual(username, empty)){
		IsRegistered[client] = false;
		Menu_Register(client, empty, empty);
	} else {
		IsRegistered[client] = true;
		if(lSettings[OtherAcc].IntValue == 0){
			Username[client] = username;
			Menu_Login(client, Username[client], empty);
		}
		else {
			Menu_Login(client, empty, empty);
		}
	}
}

public void OnConfigsExecuted() {
	char error[255];
	char db_Database[32];
	GetConVarString(g_adatbazis, db_Database, sizeof(db_Database));
	GetConVarString(lSettings[Tablename], lSettingsTableName, sizeof(lSettingsTableName));
	g_DB = SQL_Connect(db_Database, true, error, sizeof(error));
	
	char createTableQuery[4096];
	Format(createTableQuery, sizeof(createTableQuery), 
		"CREATE TABLE IF NOT EXISTS `%s` ( \
 		`Id` bigint(20) NOT NULL AUTO_INCREMENT, \
  		`username` varchar(36) COLLATE utf8_bin NOT NULL, \
  		`password` varchar(32) COLLATE utf8_bin NOT NULL, \
  		`steamid` varchar(20) COLLATE utf8_bin NOT NULL, \
  		`ipaddress` varchar(32) COLLATE utf8_bin NOT NULL, \
  		`banned` int(11) DEFAULT 0, \
 		 PRIMARY KEY (`Id`), \
  		 UNIQUE KEY `steamid` (`steamid`)  \
  		 ) ENGINE = InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;"
	, lSettingsTableName);

	SQL_TQuery(g_DB, SQLHibaKereso, createTableQuery);
}
/** Used for test purposes
stock Action Menu_Welcome(int client)
{
	if (IsClientInGame(client))
	{
		Menu menu = CreateMenu(Welcomemenu_Callback);
		menu.SetTitle("Login sytem - Welcome!\nBefore you could do anything, you have to login!");
		if(IsRegistered[client])
			menu.AddItem("login", "Login");
		else
			menu.AddItem("", "Login [ Register first ]", ITEMDRAW_DISABLED);
		if(!IsRegistered[client])
			menu.AddItem("register", "Register");
		else
			menu.AddItem("", "Register[ Already registered ]", ITEMDRAW_DISABLED);

		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int Welcomemenu_Callback(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{		
		char info[10];
		GetMenuItem(menu, itemNum, info, sizeof(info));
		if (StrEqual(info, "login"))
		{
			Menu_Login(client, empty, empty);
		}

		if (StrEqual(info, "register"))
		{
			Menu_Register(client, empty, empty);
		}
	}
}
**/
stock Action Menu_Login(int client, const char[] usrnm, const char[] usrpw)
{
	if (IsClientInGame(client))
	{
		Menu menu = CreateMenu(Loginmenu_Callback);
		if(lSettings[OtherAcc].IntValue == 0)
		{
			menu.SetTitle("Login system - Login\nEnter your password");
			char usrnml[40];
			Format(usrnml, sizeof(usrnml), "Username: %s", Username[client]);
			menu.AddItem("", usrnml, ITEMDRAW_DISABLED);
			if(StrEqual(usrpw, empty)){
				menu.AddItem("password", "Enter password");
			}
			else {
				char HasPassword[32];
				Format(Password[client], sizeof(Password[]), usrpw);
				Format(HasPassword, sizeof(HasPassword), "Password: %s", usrpw);
				menu.AddItem("", HasPassword, ITEMDRAW_DISABLED);
			}
		} else if(lSettings[OtherAcc].IntValue == 1)
		{
			menu.SetTitle("Login system - Login\nEnter your username and password");
			if(StrEqual(usrnm, empty)){
				menu.AddItem("username", "Enter username");
			}
			else {
				char HasUsername[36];
				Format(Username[client], sizeof(Username[]), usrnm);
				Format(HasUsername, sizeof(HasUsername), "Username: %s", usrnm);
				menu.AddItem("", HasUsername, ITEMDRAW_DISABLED);
			}
			if(StrEqual(usrpw, empty)){
				menu.AddItem("password", "Enter password");
			}
			else {
				char HasPassword[32];
				Format(Password[client], sizeof(Password[]), usrpw);
				Format(HasPassword, sizeof(HasPassword), "Password: %s", usrpw);
				menu.AddItem("", HasPassword, ITEMDRAW_DISABLED);
			}
		}

		menu.AddItem("", "", ITEMDRAW_SPACER);
		if(!StrEqual(Username[client], empty) && !StrEqual(Password[client], empty))
		{
			if(strlen(Username[client]) >= lSettings[Min_Name].IntValue && strlen(Password[client]) >= lSettings[Min_Pass].IntValue)
			{
				menu.AddItem("login", "Login");
			}
		} else {
			menu.AddItem("", "Login", ITEMDRAW_DISABLED);
		}

		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int Loginmenu_Callback(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{		
		char info[10];
		GetMenuItem(menu, itemNum, info, sizeof(info));
		if (StrEqual(info, "username"))
		{
			Login_U[client] = true;
			PrintToChat(client, "%s %T", PREFIX, "Enter username", client);
		}
		if (StrEqual(info, "password"))
		{
			Login_P[client] = true;
			PrintToChat(client, "%s %T", PREFIX, "Enter password", client);
		}
		if (StrEqual(info, "login"))
		{
			CheckUserCredentials(client, Username[client], Password[client]);
		}
	}
}

stock Action CheckUserCredentials(int client, const char[] usrnm, const char[] usrpw)
{
	char CredentialsQuery[1024];
	Format(CredentialsQuery, sizeof(CredentialsQuery), "SELECT * FROM `%s` WHERE username = '%s' AND password = md5('%s');", lSettingsTableName, Username[client], Password[client]);
	SQL_TQuery(g_DB, Credentials, CredentialsQuery, client);
}

public void Credentials(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	int id;
	int banned
	while (SQL_FetchRow(hndl)) {
		id = SQL_FetchIntByName(hndl, "id");
		banned = SQL_FetchIntByName(hndl, "banned");
	}

	if(banned == 1)
	{
		Menu_Login(client, Username[client], empty);
		PrintToChat(client, "%s %T", PREFIX, "User banned", client);
		return;
	}

	if(id <= 0) {
		Menu_Login(client, empty, empty);
		PrintToChat(client, "%s %T", PREFIX, "Wrong username or password", client);
	} else {
		PrintToChat(client, "%s %T", PREFIX, "Logged in", client);
		IsLoggedIn[client] = true;

		Call_StartForward(OnClientLoggedIn);
		Call_PushCell(client);
		Call_Finish();
	}
}

stock Action Menu_Register(int client, const char[] usrnm, const char[] usrpw)
{
	if (IsClientInGame(client))
	{
		Menu menu = CreateMenu(Registermenu_Callback);
		menu.SetTitle("Login sytem - Register\nOnly 1 account per steamid");
		if(StrEqual(usrnm, empty)){
			menu.AddItem("username", "Enter username");
		}
		else {
			char HasUsername[36];
			Format(Username[client], sizeof(Username[]), usrnm);
			Format(HasUsername, sizeof(HasUsername), "Username: %s", usrnm);
			menu.AddItem("", HasUsername, ITEMDRAW_DISABLED);
		}
		if(StrEqual(usrpw, empty)){
			menu.AddItem("password", "Enter password");
		}
		else {
			char HasPassword[32];
			Format(Password[client], sizeof(Password[]), usrpw);
			Format(HasPassword, sizeof(HasPassword), "Password: %s", usrpw);
			menu.AddItem("", HasPassword, ITEMDRAW_DISABLED);
		}
		menu.AddItem("", "", ITEMDRAW_SPACER);
		if(!StrEqual(Username[client], empty) && !StrEqual(Password[client], empty)){
			if(strlen(Username[client]) >= lSettings[Min_Name].IntValue && strlen(Password[client]) >= lSettings[Min_Pass].IntValue)
			{
				menu.AddItem("register", "Register");
			}
		} else {
			menu.AddItem("", "Register", ITEMDRAW_DISABLED);
		}

		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int Registermenu_Callback(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{		
		char info[10];
		GetMenuItem(menu, itemNum, info, sizeof(info));
		if (StrEqual(info, "username"))
		{
			Register_U[client] = true;
			PrintToChat(client, "%s %T", PREFIX, "Enter username", client);
		}
		if (StrEqual(info, "password"))
		{
			Register_P[client] = true;
			PrintToChat(client, "%s %T", PREFIX, "Enter password", client);
		}
		if (StrEqual(info, "register"))
		{
			char Check[1024];
			Format(Check, sizeof(Check), "SELECT id, ipaddress FROM %s WHERE username = '%s';", lSettingsTableName, Username[client]); //We're select the ID because if this username is not registered, it returns 0, what means the username is available
			SQL_TQuery(g_DB, Checkusernames, Check, client);
		}
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	if (IsLoggedIn[client])
		return Plugin_Continue;

	if (!IsLoggedIn[client])
	{
		if(Register_U[client])
		{
			if(strlen(args) >= lSettings[Min_Name].IntValue)
			{
				Menu_Register(client, args, empty);
				Register_U[client] = false;
			} else {
				PrintToChat(client, "%s %T", PREFIX, "Username too short", client);
			}
		} else if(Register_P[client])
		{
			if(strlen(args) >= lSettings[Min_Pass].IntValue)
			{
				Menu_Register(client, Username[client], args);
				Register_P[client] = false;
			} else {
				PrintToChat(client, "%s %T", PREFIX, "Password too short", client);
			}
		} else if(Login_U[client]){
			Menu_Login(client, args, empty);
			Login_U[client] = false;
		}  else if(Login_P[client]){
			Menu_Login(client, Username[client], args);
			Login_P[client] = false;
		} else if(!Register_P[client] || !Register_U[client] || Login_U[client] || Login_P[client]){
			PrintToChat(client, "%s %T", PREFIX, "Not logged in", client);
		}

		if(IsRegistered[client])
		{
			if(lSettings[OtherAcc].IntValue == 0)
			{
				if(!StrEqual(Username[client], empty))
				{
					if(StrEqual(Password[client], empty))
					{
						Menu_Login(client, Username[client], empty);
					}
					else if(!StrEqual(Password[client], empty)){
						Menu_Login(client, Username[client], Password[client]);
					}
				}
			} else if(lSettings[OtherAcc].IntValue == 1)
			{
				if(!StrEqual(Username[client], empty)) {
					if(StrEqual(Password[client], empty))
					{
						Menu_Login(client, Username[client], empty);
					}
					else {
						Menu_Login(client, Username[client], Password[client]);
					}
				} else {
					Menu_Login(client, empty, empty);
				}
			}
		} else if(!IsRegistered[client])
		{
			if(StrEqual(Username[client], empty) && StrEqual(Password[client], empty))
			{
				if(!Register_U[client])
				{
					if(!Register_P[client])
					{
						Menu_Register(client, empty, empty);
					}
				}
			} else if(!StrEqual(Username[client], empty))
			{
				if(!StrEqual(Password[client], empty))
				{
					Menu_Register(client, Username[client], Password[client]);
				}
			}
		}

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void Checkusernames(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	int id;
	char fetchip[32];
	while (SQL_FetchRow(hndl)) {
		id = SQL_FetchIntByName(hndl, "id");
		SQL_FetchString(hndl, 1, fetchip, sizeof(fetchip));
	}

	char clientip[32];
	GetClientIP(client, clientip, sizeof(clientip));

	if(!StrEqual(clientip, fetchip))
	{
		if(id <= 0)
			Register_Client(client);
		else {
			PrintToChat(client, "%s %T", PREFIX, "Username registered", client);
			Menu_Register(client, empty, Password[client]);
		}
	} else {
		PrintToChat(client, "%s %T", PREFIX, "Same ip", client);
	}
}

stock Action Register_Client(int client)
{
	char jatekosnev[MAX_NAME_LENGTH + 8];
	char steamid[20];
	char clientip[32];
	char teljes_jatekosnev[MAX_NAME_LENGTH * 2 + 16];

	GetClientName(client, jatekosnev, sizeof(jatekosnev));
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	GetClientIP(client, clientip, sizeof(clientip));

	SQL_EscapeString(g_DB, jatekosnev, teljes_jatekosnev, sizeof(teljes_jatekosnev));

	char RegisterQuery[2024];
	Format(RegisterQuery, sizeof(RegisterQuery), "INSERT INTO `%s` (`Id`, `username`, `password`, `steamid`, `ipaddress`, `banned`) VALUES (NULL, '%s', md5('%s'), '%s', '%s', '0');", lSettingsTableName, Username[client], Password[client], steamid, clientip);
	SQL_TQuery(g_DB, SQLHibaKereso, RegisterQuery);

	PrintToChat(client, "%s %T", PREFIX, "Succesfully registered", client);
	IsRegistered[client] = true;
	Menu_Login(client, Username[client], empty);
}

public Action Command_Logout(int client, int args)
{
	if (IsClientInGame(client))
	{
		if(!IsLoggedIn[client])
		{
			PrintToChat(client, "%s %T", PREFIX, "Can't logout", client);
			return Plugin_Handled;
		}

		PrintToChat(client, "%s %T", PREFIX, "Logged out", client);
		ChangeClientTeam(client, 1);

		IsLoggedIn[client] = false;
		Password[client] = empty;

		Call_StartForward(OnClientLoggedOut);
		Call_PushCell(client);
		Call_Finish();
	}

	return Plugin_Continue;
}

public Action Command_LSBan(int client, int args)
{
	if (args != 1)
	{
		PrintToChat(client, "%s %T", PREFIX, "Usage", client);
		return Plugin_Handled;
	}

	char target[MAX_NAME_LENGTH];
	GetCmdArg(1, target, sizeof(target));
	int celpont = FindTarget(client, target, true);

	if (!IsValidClient(celpont))
	{
		PrintToChat(client, "%s %T", PREFIX, "Invalid target", client);
		return Plugin_Handled;
	}

	char jatekosnev[MAX_NAME_LENGTH + 8];
	GetClientName(celpont, jatekosnev, sizeof(jatekosnev));
	char steamid[20];
	GetClientAuthId(celpont, AuthId_Steam2, steamid, sizeof(steamid));
	char BanUserQuery[2024];

	Format(BanUserQuery, sizeof(BanUserQuery), "UPDATE `%s` SET `banned` = 1 WHERE `%s`.`steamid` = '%s';", lSettingsTableName, lSettingsTableName, steamid);
	SQL_TQuery(g_DB, SQLHibaKereso, BanUserQuery);

	PrintToChatAll("%s \x04%s \x01have been banned from the login system", PREFIX, jatekosnev);
	ClientCommand(celpont, "sm_logout");

	Call_StartForward(OnClientGotBanned);
	Call_PushCell(client);
	Call_Finish();

	return Plugin_Continue;
}

public void SQLHibaKereso(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

public int Native_IsLoggedIn(Handle myplugin, int argc)
{
	int client = GetNativeCell(1);

	return IsLoggedIn[client];
}

stock bool IsAct(int client)
{
	if(Register_U[client] || Register_P[client] || Login_U[client] || Login_P[client])
		return true;
	else
		return false;
}

stock bool IsClientLoggedIn(int client)
{
	return IsLoggedIn[client];
}

stock SQL_FetchIntByName(Handle query, const char[] fieldName, &DBResult:result=DBVal_Error) {
	
	int fieldNum;
	SQL_FieldNameToNum(query, fieldName, fieldNum);
	
	return SQL_FetchInt(query, fieldNum, result);
}