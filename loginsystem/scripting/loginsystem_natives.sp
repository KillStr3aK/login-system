#include <sourcemod>
#include <loginsystem>

#define PLUGIN_NEV	"Native examples"
#define PLUGIN_LERIAS	"Native examples for loginsystem"
#define PLUGIN_AUTHOR	"Nexd"
#define PLUGIN_VERSION	"1.0"
#pragma tabsize 0

public Plugin myinfo = 
{
	name = PLUGIN_NEV,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_LERIAS,
	version = PLUGIN_VERSION
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_isloggedin", Command_IsClientLoggedIn);

	LoadTranslations("common.phrases");
}

public Action Command_IsClientLoggedIn(int client, int args)
{
	char playername[MAX_NAME_LENGTH+1];
	char player[MAX_NAME_LENGTH];
	GetCmdArg(1, player, sizeof(player));
	int celpont = FindTarget(client, player, true);

	if(!IsValidClient(celpont))
	{
		PrintToChat(client, "Invalid player");
		return Plugin_Handled;
	}

	GetClientName(celpont, playername, sizeof(playername));
	if(LS_IsLoggedIn(client))
		PrintToChat(client, "%s is logged in.", playername);
	else
		PrintToChat(client, "%s isn't logged in.", playername);

	return Plugin_Continue;
}

public void LS_OnClientLoggedIn(int client)
{
	char playername[MAX_NAME_LENGTH+1];
	GetClientName(client, playername, sizeof(playername));
	PrintToChatAll("%s has logged in.", playername); 
}

public void LS_OnClientLoggedOut(int client)
{
	char playername[MAX_NAME_LENGTH+1];
	GetClientName(client, playername, sizeof(playername));
	PrintToChatAll("%s has logged out.", playername); 
}

public void LS_OnClientGotBanned(int client)
{
	char playername[MAX_NAME_LENGTH+1];
	GetClientName(client, playername, sizeof(playername));
	PrintToChatAll("%s has been banned.", playername); 
}